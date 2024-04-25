# Utility functions
fatal_if_undefined = $(if $(findstring undefined,$(origin $1)),$(error $1 is not set))
first_existing_file = $(firstword $(wildcard $1))
first_existing_file_or_default = $(firstword $(wildcard $1) $(firstword $1))

# Utility variables
current_makefile := $(lastword $(MAKEFILE_LIST))
current_makefile_directory := $(dir $(current_makefile))
olm_base_dir := $(current_makefile_directory)/base

# Default config
olm_publish_repos ?= 
oci_olm_image_tag ?= $(VERSION)
preflight_container_project_ids ?=

# The example directory is used to find CRD examples, this is used to create the
# alm-examples annotation in the clusterserviceversion
olm_example_directory ?= deploy/examples

# Base directory for OLM bundle
olm_bundle_base := bundle
olm_manifests_base := $(olm_bundle_base)/manifests
olm_metadata_base := $(olm_bundle_base)/metadata
olm_scorecard_base := $(olm_bundle_base)/tests/scorecard

# We want to allow both the .yml and .yaml extension, so we use wildcard to find 
# the file.
olm_clusterserviceversion_path ?= $(call first_existing_file_or_default,$(olm_manifests_base)/$(deploy_name).clusterserviceversion.yaml $(olm_manifests_base)/$(deploy_name).clusterserviceversion.yml)
olm_additional_manifests ?= $(filter-out $(olm_clusterserviceversion_path),$(wildcard $(olm_manifests_base)/*.yaml  $(olm_manifests_base)/*.yml))
olm_annotations_path ?= $(call first_existing_file,$(olm_metadata_base)/annotation.yml $(olm_metadata_base)/annotation.yaml)
olm_scorecard_config_path ?= $(call first_existing_file,$(olm_scorecard_base)/config.yml $(olm_scorecard_base)/config.yaml)
olm_icon_path ?= $(call first_existing_file,$(olm_bundle_base)/icon.png)
olm_helm_value_path ?= $(call first_existing_file,$(olm_bundle_base)/values.yaml $(olm_bundle_base)/values.yml)

# Validate
$(call fatal_if_undefined,oci_olm_image_tag)

# Add OLM as a push target to the oci-publish module
ifdef oci_olm_image_name
push_names += olm
endif

oci_digest_path_olm := $(bin_dir)/scratch/image/oci-layout-olm.$(oci_olm_image_tag).digests
oci_layout_path_olm := $(bin_dir)/scratch/image/oci-layout-olm.$(oci_olm_image_tag)

generate-olm-project: | $$(NEEDS_YQ)
	cp -r $(olm_base_dir)/. ./
	$(YQ) -i  '.projectName = "$(deploy_name)"' PROJECT

shared_generate_targets += generate-olm-project

