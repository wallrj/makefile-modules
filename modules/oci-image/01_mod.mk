# Copyright 2023 The cert-manager Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ifndef bin_dir
$(error bin_dir is not set)
endif

ifndef oci_platforms
$(error oci_platforms is not set)
endif

ifndef build_names
$(error build_names is not set)
endif

fatal_if_undefined = $(if $(findstring undefined,$(origin $1)),$(error $1 is not set))

define check_variables
$(call fatal_if_undefined,go_$1_ldflags)
$(call fatal_if_undefined,go_$1_source_path)
$(call fatal_if_undefined,oci_$1_base_image)
$(call fatal_if_undefined,oci_$1_image_name)
$(call fatal_if_undefined,oci_$1_image_name_development)
endef

$(foreach build_name,$(build_names),$(eval $(call check_variables,$(build_name))))

##########################################

CGO_ENABLED ?= 0

build_targets := $(build_names:%=$(bin_dir)/bin/%)
run_targets := $(build_names:%=run-%)
oci_build_targets := $(build_names:%=oci-build-%)
oci_push_targets := $(build_names:%=oci-push-%)
oci_load_targets := $(build_names:%=oci-load-%)

image_tool_dir := $(dir $(lastword $(MAKEFILE_LIST)))/image_tool/

$(bin_dir)/bin:
	mkdir -p $@

## Build manager binary.
## @category [shared] Build
$(build_targets): $(bin_dir)/bin/%: FORCE | $(NEEDS_GO) $(bin_dir)/bin
	CGO_ENABLED=$(CGO_ENABLED) \
	$(GO) build \
		-ldflags '$(go_$*_ldflags)' \
		-o $@ \
		$(go_$*_source_path)

.PHONY: $(run_targets)
ARGS ?= # default empty
## Run a controller from your host.
## @category [shared] Build
$(run_targets): run-%: | $(NEEDS_GO)
	$(GO) run \
		-ldflags '$(go_$*_ldflags)' \
		$(go_$*_source_path) $(ARGS)

.PHONY: $(oci_build_targets)
## Build the oci image.
## @category [shared] Build
$(oci_build_targets): oci-build-%: | $(NEEDS_KO) $(NEEDS_GO) $(NEEDS_YQ) $(bin_dir)/scratch/image
	$(eval oci_layout_path := $(bin_dir)/scratch/image/oci-layout-$*.$(oci_$*_image_tag))
	rm -rf $(CURDIR)/$(oci_layout_path)
	
	echo '{}' | \
		$(YQ) '.defaultBaseImage = "$(oci_$*_base_image)"' | \
		$(YQ) '.builds[0].id = "$*"' | \
		$(YQ) '.builds[0].main = "$(go_$*_source_path)"' | \
		$(YQ) '.builds[0].env[0] = "CGO_ENABLED={{.Env.CGO_ENABLED}}"' | \
		$(YQ) '.builds[0].ldflags[0] = "-s"' | \
		$(YQ) '.builds[0].ldflags[1] = "-w"' | \
		$(YQ) '.builds[0].ldflags[2] = "{{.Env.LDFLAGS}}"' \
		> $(CURDIR)/$(oci_layout_path).ko_config.yaml

	KOCACHE=$(bin_dir)/scratch/image/ko_cache \
	KO_CONFIG_PATH=$(CURDIR)/$(oci_layout_path).ko_config.yaml \
	LDFLAGS="$(go_$*_ldflags)" \
	CGO_ENABLED=$(CGO_ENABLED) \
	$(KO) build $(go_$*_source_path) \
		--platform=$(oci_platforms) \
		--oci-layout-path=$(CURDIR)/$(oci_layout_path) \
		--sbom-dir=$(CURDIR)/$(oci_layout_path).sbom \
		--sbom=spdx \
		--push=false \
		--base-import-paths

	cd $(image_tool_dir) && $(GO) run . list-digests \
		$(CURDIR)/$(oci_layout_path) \
		> $(CURDIR)/$(oci_layout_path).digests

.PHONY: $(oci_push_targets)
## Push docker image with the manager.
## Expected pushed images:
## - :v1.2.3, @sha256:0000001
## - :v1.2.3.sig, :sha256-0000001.sig
## @category [shared] Build
$(oci_push_targets): oci-push-%: oci-build-% | $(NEEDS_CRANE) $(NEEDS_COSIGN) $(NEEDS_YQ) $(bin_dir)/scratch/image
	$(eval oci_layout_path := $(bin_dir)/scratch/image/oci-layout-$*.$(oci_$*_image_tag))
	$(eval image_ref := $(shell head -1 $(CURDIR)/$(oci_layout_path).digests))

	if $(CRANE) image digest $(oci_$*_image_name)@$(image_ref) >/dev/null 2>&1; then \
		echo "Tag already exists, exiting"; \
		exit 1; \
	else \
		echo "Tag does not yet exist, pushing image"; \
	fi

	$(CRANE) push "$(oci_layout_path)" "$(oci_$*_image_name):$(oci_$*_image_tag)"
	$(COSIGN) sign --yes=true "$(oci_$*_image_name)@$(image_ref)"

.PHONY: $(oci_load_targets)
## Load docker image with the manager.
## @category [shared] Build
$(oci_load_targets): oci-load-%: oci-build-% | kind-cluster $(NEEDS_KIND)
	$(eval oci_layout_path := $(bin_dir)/scratch/image/oci-layout-$*.$(oci_$*_image_tag))

	cd $(image_tool_dir) && $(GO) run . convert-to-docker-tar $(CURDIR)/$(oci_layout_path) $(CURDIR)/$(oci_layout_path).docker.tar $(oci_$*_image_name_development):$(oci_$*_image_tag)
	$(KIND) load image-archive --name $(kind_cluster_name) $(oci_layout_path).docker.tar
