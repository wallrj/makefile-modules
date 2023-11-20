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

MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
SHELL := /usr/bin/env bash
.SHELLFLAGS := -uo pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:
FORCE:

noop: # do nothing

##################################
# Host OS and architecture setup #
##################################

# The reason we don't use "go env GOOS" or "go env GOARCH" is that the "go"
# binary may not be available in the PATH yet when the Makefiles are
# evaluated. HOST_OS and HOST_ARCH only support Linux, *BSD and macOS (M1
# and Intel).
HOST_OS ?= $(shell uname -s | tr A-Z a-z)
HOST_ARCH ?= $(shell uname -m)
ifeq (x86_64, $(HOST_ARCH))
	HOST_ARCH = amd64
endif

##################################
# Git and versioning information #
##################################

VERSION ?= $(shell git describe --tags --always --match='v*' --abbrev=14 --dirty)
GITCOMMIT := $(shell git rev-parse HEAD)

##################################
# Global variables and dirs      #
##################################

bin_dir := _bin

$(bin_dir) $(bin_dir)/scratch:
	mkdir -p $@

##################################
# Include all the Makefiles      #
##################################

-include make/00_mod.mk
-include make/_shared/*/00_mod.mk
-include make/_shared/*/01_mod.mk
-include make/02_mod.mk
-include make/_shared/*/02_mod.mk
