# BlueBuild Repo for Unidentified Device [![bluebuild build badge](https://github.com/blue-build/template/actions/workflows/build.yml/badge.svg)](https://github.com/blue-build/template/actions/workflows/build.yml)

This repo contains the configuration of the [Aurora Linux](https://getaurora.dev/) base image running my not-really-a-Mac-anymore PC
named Unidentified Device. (yes, really)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based
on the original template from which this repo was created.

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own
> discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:

```shell
rpm-ostree rebase ostree-unverified-registry:ghcr.io/blue-build/template:latest
```

- Reboot to complete the rebase:

```shell
systemctl reboot
```

- Then rebase to the signed image, like so:

```shell
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/blue-build/template:latest
```

- Reboot again to complete the installation

```shell
systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in
`recipe.yml`, so you won't get accidentally updated to the next major version.

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available
[here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on
GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify
the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/blue-build/template
```
