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

When developing a new module, put your targets in `01_mod.mk`.
This is to ensure that the targets for downloading tool dependencies such as
`NEEDS_XYZ` are included first and can be resolved.

To test changes that you make in *this* repository:
1. Open a branch in a *target repository* that consumes the new or changed module. E.g. approver-policy.
2. Update the `klone.yaml` file in the target repository with a reference to the branch and commit containing the changes in *this* repository.
3. Run `make upgrade-klone` in the target repository, to pull in your changes.
4. Test the new or changed `make` target in the target repository.
5. Fix any problems by pushing changes to your branch in *this* repository.
6. Go to step 3 to pull latest changes into the target repository and then retest.

### Upgrading the tools in the tools module

1. bump the versions in the modules/tools/00_mod.mk file
2. run `make tools-learn-sha`

See [Makefile](./Makefile) for more details.
