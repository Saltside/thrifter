THRIFT:=vendor/gen-rb/test_types.rb

BUNDLE:=tmp/bundle
DOCKER_IMAGES:=tmp/docker_images

BUNDLE_IMAGE:=thrifter/bundle

$(THRIFT): test.thrift
	mkdir -p $(@D)
	thrift -o vendor --gen rb test.thrift

$(DOCKER_IMAGES):
	mkdir -p $(@D)
	touch $@
		
$(BUNDLE): Dockerfile thrifter.gemspec
	docker build -t $(BUNDLE_IMAGE) .
	docker inspect -f '{{ .Id }}' $(BUNDLE_IMAGE) >> $(DOCKER_IMAGES)

.PHONY: test
# For quick and easy access to the most common thing
test: test-lib

.PHONY: test-lib
test-lib: $(THRIFT) $(BUNDLE)
	docker run --rm -it -v $(CURDIR):/app $(BUNDLE_IMAGE) bundle exec rake test

.PHONY: test-ci
test-ci: test-lib test-monkey

.PHONY: test-monkey
test-monkey: teardown
	docker run -d -v $(CURDIR):/app --name server $(BUNDLE_IMAGE) script/server
	docker run --rm -it --link server:server -v $(CURDIR):/app \
		$(BUNDLE_IMAGE) script/monkey-client server:9090

.PHONY:
release:
	bundle exec rake release

.PHONY: treadown
teardown:
	-docker stop server 2> /dev/null
	-docker rm server 2> /dev/null

.PHONY: clean
clean: $(DOCKER_IMAGES) teardown
	-sort -u $(DOCKER_IMAGES) | xargs --no-run-if-empty docker rmi 2> /dev/null
	rm -f $(DOCKER_IMAGES) $(APP)
