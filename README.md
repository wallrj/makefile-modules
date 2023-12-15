# makefile-modules
Reusable Makefile modules that can be kloned into your project

## Usage

The modules in this repository are meant to be copied into your project and then included in your `Makefile`.
To copy the modules, the [klone tool](https://github.com/cert-manager/klone) is recommended.
The [klone module](./modules/klone/) provides a make target that can be used to update all modules in your repository (including the klone module itself),
it fetches the latest version of the modules from this repository. The klone module is automatically downloaded by the [tools module](./modules/tools/).
An example `Makefile` that can be used to import the copied modules is provided in the [repository-base module](./modules/repository-base/base/Makefile).
The repository-base module provides a generate and verify make target that can be used to keep these files in the root of your repository up to date.
Additionally, the repository-base module provisions a GitHub action that periodically checks that the kloned modules are up to date (using the [klone module](./modules/klone/)).

## Example repository layout

The following example shows how the modules can be used in a repository.

```
.
├── ...
├── Makefile                 # managed by the repository-base module
├── make
│   ├── _shared              # shared makefiles, kloned from this repository
│   │   ├── module1
│   │   │   ├── 00_mod.mk
│   │   │   ├── 01_mod.mk
│   │   │   ├── 02_mod.mk
│   │   │   └── ...
│   │   ├── module2
│   │   │   └── ...
│   │   └── ...
│   ├── 00_mod.mk            # repo-specific variables
│   ├── 02_mod.mk            # repo-specific targets
│   └── ...
```

The order in which the makefiles are includes is as follows (see [Makefile](./modules/repository-base/base/Makefile))):
```
-include make/00_mod.mk
-include make/_shared/*/00_mod.mk
-include make/_shared/*/01_mod.mk
-include make/02_mod.mk
-include make/_shared/*/02_mod.mk
```
