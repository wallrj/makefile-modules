# Utility variables
current_makefile = $(lastword $(MAKEFILE_LIST))
current_makefile_directory = $(dir $(current_makefile))
comma := ,

# Utility functions
for_each_kv = $(foreach item,$2,$(eval $(call $1,$(word 1,$(subst =, ,$(item))),$(word 2,$(subst =, ,$(item))))))
fatal_if_undefined = $(if $(findstring undefined,$(origin $1)),$(error $1 is not set))

# Build up config
olm_bundle_dir := $(bin_dir)/scratch/olm/bundle-$(oci_olm_image_tag)

# Build the olm-to-oci tool
olm_to_oci_dir := $(current_makefile_directory:/=)/olm-to-oci
OLM-TO-OCI := $(CURDIR)/$(bin_dir)/tools/olm-to-oci
NEEDS_OLM-TO-OCI := $(bin_dir)/tools/olm-to-oci
$(NEEDS_OLM-TO-OCI): $(wildcard $(olm_to_oci_dir)/*.go) | $(NEEDS_GO)
	cd $(olm_to_oci_dir) && GOWORK=off GOBIN=$(CURDIR)/$(dir $@) $(GO) install .

# Get all example files
olm_examples := $(wildcard $(olm_example_directory)/*.yaml $(olm_example_directory)/*.yml)

.PHONY: olm-bundle
olm-bundle: $(helm_chart_archive) $(olm_clusterserviceversion_path) | $(NEEDS_HELM) $(NEEDS_YQ) $(NEEDS_OPERATOR-SDK)
	rm -rf $(olm_bundle_dir) $(oci_layout_path_olm) $(oci_digest_path_olm)
	mkdir -p $(olm_bundle_dir)
	cd $(olm_bundle_dir) && $(HELM) template $(addprefix --values=,$(abspath $(olm_helm_value_path))) $(deploy_name) $(CURDIR)/$(helm_chart_archive) |\
		$(YQ) 'del(.metadata.annotations["helm.sh/resource-policy"])' |\
		$(YQ) 'del(.metadata.labels["app.kubernetes.io/managed-by"])' |\
		$(YQ) 'del(.metadata.labels["app.kubernetes.io/version"])' |\
		$(YQ) 'del(.metadata.labels["helm.sh/chart"])' |\
		$(YQ) 'del(.metadata.creationTimestamp)' |\
		$(YQ) - $(abspath $(olm_clusterserviceversion_path)) $(abspath $(olm_examples)) $(abspath $(olm_additional_manifests)) |\
		$(OPERATOR-SDK) generate bundle --output-dir . --package $(deploy_name) --version $(VERSION:v%=%)
	
	@# Set the container image annodation
	$(YQ) -i '.metadata.annotations.containerImage = .spec.install.spec.deployments[0].spec.template.spec.containers[0].image' $(olm_bundle_dir)/manifests/$(deploy_name).clusterserviceversion.yaml 

	@# Set the supported OS/Arches based on $(oci_platforms)
	$(YQ) -i --string-interpolation '. * ("$(oci_platforms)" | [ split(",").[] | split("/") | ["operatorframework.io/os.\(.[0])", "operatorframework.io/arch.\(.[1])"] ] | [ .[][] ] | unique | .[] as $$item ireduce({}; . * {"metadata": {"annotations": {$$item: "supported"}}}))' $(olm_bundle_dir)/manifests/$(deploy_name).clusterserviceversion.yaml 
	
	@# Set the openshift version
	$(YQ) -i '.annotations."com.redhat.openshift.versions"="v4.6"' $(olm_bundle_dir)/metadata/annotations.yaml

	@# Merge in custom annotations
	$(YQ) eval-all -i '. as $$item ireduce ({}; . * $$item )' $(olm_bundle_dir)/metadata/annotations.yaml $(olm_annotations_path)

	@# Copy in scorecard config
	$(if $(olm_scorecard_config_path),mkdir -p $(olm_bundle_dir)/tests/scorecard && cp $(olm_scorecard_config_path) $(olm_bundle_dir)/tests/scorecard/config.yaml)
	
	@# Set the icon in the clusterserviceversion
	$(if $(olm_icon_path),cat $(olm_icon_path) | base64 | tr -d '\n' | $(YQ) eval-all -i '.spec.icon = [{"mediatype": "image/png"$(comma) "base64data": select(fi == 1)}] | select(fi == 0)' $(olm_bundle_dir)/manifests/$(deploy_name).clusterserviceversion.yaml -)

	@# Set the displayName and description of CRDs
	$(YQ) eval-all -i '.spec.customresourcedefinitions.owned = [ select(.kind == "CustomResourceDefinition") | {"kind": .spec.names.kind$(comma) "name": .metadata.name$(comma) "displayName": .spec.names.kind$(comma) "version": (.spec.versions[] | select(.storage == true) | .name)$(comma)"description": (.spec.versions[] | select(.storage == true) | .schema.openAPIV3Schema.description)} ] | select(fi == 0)' $(olm_bundle_dir)/manifests/$(deploy_name).clusterserviceversion.yaml $(olm_bundle_dir)/manifests/*.yaml

.PHONY: oci-build-olm
## Generate OCI directory for OLM bundle
## @category [shared] Build
oci-build-olm: olm-bundle | $(NEEDS_OLM-TO-OCI)
	$(OLM-TO-OCI) $(olm_bundle_dir) $(oci_layout_path_olm)

# $1 upstream repo
# $2 fork
define olm_publish_targets
.PHONY: olm-publish-$(subst /,-,$1)
olm-publish-$(subst /,-,$1): olm-bundle | $(NEEDS_GH) $(bin_dir)/scratch
	mkdir -p $(bin_dir)/scratch/git/$(dir $2)
	$(GH) repo clone $2 $(bin_dir)/scratch/git/$2
	cd $(bin_dir)/scratch/git/$2 && \
		git checkout -B $(VERSION) && \
		cp $(abspath $(olm_bundle_dir)) operators/$(deploy_name)/$(VERSION) && \
		git add operators/$(deploy_name)/$(VERSION) && \
		git commit -m "$(deploy_name) ($(VERSION))" && \
		git push origin $(VERSION) && \
		$(GH) pr create --repo $1 --head $(firstword $(subst /, ,$2)):$(VERSION)

olm-publish: olm-publish-$(subst /,-,$1)
endef

$(call for_each_kv,olm_publish_targets,$(olm_publish_repos))

.PHONY: olm-publish
## Publish the OLM bundle to an upstream repo, the GH_TOKEN environment variable
## is required to exist
## @category [shared] Publish
olm-publish:

.PHONY: preflight-scan
## Scan the published image using preflight
## @category [shared] Publish
preflight-scan:

define preflight_scan_targets
.PHONY: preflight-scan-$1
preflight-scan-$1: | $$(NEEDS_PREFLIGHT)
	$$(call fatal_if_undefined,PYXIS_API_TOKEN)
	$$(PREFLIGHT) check container --certification-project-id $2 --pyxis-api-token $$(PYXIS_API_TOKEN) $(filter $1:%,$(foreach build_name,$(build_names),$(addsuffix :$(call oci_image_tag_for,$(build_name)),$(call oci_image_names_for,$(build_name)))))

preflight-scan: preflight-scan-$1
endef

$(call for_each_kv,preflight_scan_targets,$(preflight_container_project_ids))
