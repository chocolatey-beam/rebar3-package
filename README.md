# Chocolatey Package for Rebar3

https://community.chocolatey.org/packages/rebar3

# Release

Open PowerShell in Administrator mode and navigate to the clone of the  `chocolatey-beam/rebar3-package` repository.

Run

```
.\package.ps1 -PackAndTest
```

When satisfied, run the following to push the package:

```
.\package.ps1 -ApiKey <ApiKey> -Push

```

The ApiKey can be found in your account settings at https://community.chocolatey.org/users/account/LogOn
