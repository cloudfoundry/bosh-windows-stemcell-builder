GOSRC = $(shell find . -name "*.go" ! -name "*test.go" ! -name "*fake*" ! -path "./integration/*")
STEMCELL_VERSION = $(shell echo "$${STEMBUILD_VERSION}")
LD_FLAGS = "-w -s -X github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version.Version=${STEMCELL_VERSION}"

ifeq ($(OS),Windows_NT)
	COMMAND = out/stembuild.exe
	CP = cp
else
	UNAME = $(shell uname -s)
	COMMAND = out/stembuild

	ifeq ($(UNAME),Darwin)
		CP = cp -p
	else ifeq ($(UNAME),Linux)
		CP = cp --preserve=mode,ownership
	endif
endif

all : test build

build : out/stembuild

build-integration : generate-fake-stemcell-automation $(GOSRC)
	go build -o $(COMMAND) -ldflags $(LD_FLAGS) .

clean :
	rm -rf version/version.go assets/StemcellAutomation.zip assets/local/* out/*

format :
	go fmt ./...

integration : generate-fake-stemcell-automation
	go run github.com/onsi/ginkgo/v2/ginkgo -r -vv --randomize-all --keep-going --flake-attempts 2 --timeout 3h --output-interceptor-mode=none integration

integration/construct : generate-fake-stemcell-automation
	go run github.com/onsi/ginkgo/v2/ginkgo -r -v --randomize-all --keep-going --flake-attempts 2 --timeout 3h --output-interceptor-mode=none integration/construct

integration-badger : generate-fake-stemcell-automation
	go run github.com/onsi/ginkgo/v2/ginkgo -r -v --randomize-all --until-it-fails --timeout 3h integration

generate-fake-stemcell-automation:
	$(CP) integration/construct/assets/StemcellAutomation.zip assets/

out/stembuild : assets $(GOSRC)
	CGO_ENABLED=0 go build -o $(COMMAND) -ldflags $(LD_FLAGS) .

out/stembuild.exe : assets $(GOSRC)
	GOOS=windows CGO_ENABLED=0 go build -o out/stembuild.exe -ldflags $(LD_FLAGS) .

test : units

units : format generate-fake-stemcell-automation
	@go run github.com/onsi/ginkgo/v2/ginkgo version
	go run github.com/onsi/ginkgo/v2/ginkgo -r --randomize-all --randomize-suites --keep-going --skip-package integration,iaas_cli
	@echo ""
	@echo "SWEET SUITE SUCCESS"

contract :
	go run github.com/onsi/ginkgo/v2/ginkgo -r --randomize-all --randomize-suites --keep-going --flake-attempts 2 iaas_cli

.PHONY : all build build-integration clean format generate-fake-stemcell-automation
.PHONY : test units units-full integration integration-tests-full

assets/StemcellAutomation.zip:
	@echo "Unable to locate assets/StemcellAutomation.zip. This file is bundled into the final stembuild executable and must be present. Please see README.md on how to construct this file."
	exit 1
