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

###################################################################################

# This makefile can be used to learn hashes for the tools Makefile module.
# To upgrade the tools in the tools module:
# 1. bump the versions in the modules/tools/00_mod.mk file
# 2. run `make tools-learn-sha`

###################################################################################

MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
SHELL := /usr/bin/env bash
.SHELLFLAGS := -uo pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:
FORCE:

bin_dir := _bin

$(bin_dir):
	mkdir -p $@

include modules/tools/00_mod.mk

.PHONY: help
help: ## Show this help
	@echo "Usage: make [target] ..."
	@echo
	@echo "make tools-learn-sha"
