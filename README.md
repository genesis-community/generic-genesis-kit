Generic Genesis Kit
===================

The main manifest file is `ops/base.yml`. This file is shared across the deployments. Edits to this file will apply to all deployments. Use overrides in deployment env files for deployment specific changes (ex. `env.yml`).

The top section of the `ops/base.yml` file, `meta`, hold the parameters that are loaded into properties in the `instance_groups` section below using spruce `(( grab ... ))` functions. Entries labelled with `(( param ... ))` are expected as parameters within the env files.

You can specify any secrets via the `kit-overrides.yml` file, in the same format as used by regular Genesis kits.  See Genesis docs/AUTHORING-KITS.md for instructions regarding specifying credentials and certificates, or any of the other Genesis kits found under the `genesis-community` organization on Github.  If your deployment uses credhub instead, you can specify `secret-store: credhub` as a top-level key/value in the `kit-overrides.yml` file instead.

Finally, if you want to add functionality via scripts that operate on specific environments, you can add these script to the `addons/` directory in your repository.  The scripts have to be executable on whatever platform they will be run on, so it is recommended that you use bash or perl as they are already known to be required and available for Genesis.  The script has to support the following arguments: `help` that prints out the usage information, and `run` that performs the desired action.
