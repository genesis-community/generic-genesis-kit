# Generic Genesis Kit 2.0.0

This release adds the `resolute` feature and moves every hook to Perl, so the kit now needs Genesis 3.1.0 or newer.

## New features

- **The resolute feature**
  Adding `resolute` to an environment's features deploys it on the Ubuntu resolute stemcell.  Before each deploy, the kit refuses a resolute manifest that ships bpm older than 1.4.41 or `latest`, because older bpm doesn't compile on resolute.  It also refuses one that names any other stemcell.  The MANUAL covers each check.

- **PVE cloud config**
  The cloud-config hook now provides PVE properties for the network, the VM type, and the disk type, with sizes that can be set under `bosh-configs.cpi`.

- **The execute addon**
  `genesis <env> do execute <script>` runs a script from the repository's `addons/` directory, even when its name matches one of the kit's addons.

## Changes that need attention

- **Genesis 3.1.0 is the floor**
  The bash `blueprint` and `new` hooks are gone, so older Genesis releases can't use this kit.

- **`params.stemcell_version` is honoured**
  The old `base.yml` read only `meta.stemcell_version`, so an environment that set the params key still deployed the `latest` stemcell.  The params key now wins over the meta key.  Remove a stale `params.stemcell_version` before upgrading, or the next deploy may move to an older stemcell and recreate every VM.  The kit warns when the two keys disagree.

- **`params.stemcell_os: ubuntu-resolute` needs the feature**
  An environment that switched to resolute by setting that param must now use the `resolute` feature and drop the param, or the manifest won't build.

- **`do h` runs health**
  The help addon is now called `usage`, or `u`, so `h` resolves to `health`.  Repository scripts named after a kit addon only run through `do execute`.

- **`do health` fails on an unhealthy deployment**
  The single-run health check exits non-zero unless every instance is running, which suits scripts and pipelines.

- **`genesis new` writes the file without opening an editor**
  The new environment file has the kit, features, genesis, and params blocks, and you edit it afterwards.

## Fixes

- The Perl hooks that develop shipped failed to load under Genesis 3.2, and they work again.

- The health addon reads the fields that `bosh instances` actually returns, so it no longer reports a healthy deployment as unhealthy.

- The usage and execute addons list the repository's scripts themselves, so they no longer depend on the bash `addon` hook.
