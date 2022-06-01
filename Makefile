REPO_NAME := $(patsubst %.git,%,$(shell git config --get remote.origin.url))
IMG_NAME := $(notdir $(patsubst %/,%,$(dir $(REPO_NAME))))/$(notdir $(REPO_NAME))
IMG_TAG := $(shell git rev-parse --verify --short HEAD)

.PHONY: all
all:
	docker build --pull=true --rm -t $(IMG_NAME):$(IMG_TAG) --build-arg HOSTNAME=email.sink .
	#docker push $(IMG_NAME):$(IMG_TAG) .
