# Yolks

A curated collection of core images that can be used with Pterodactyl's Egg system. Each image is rebuilt
periodically to ensure dependencies are always up-to-date.

Images are hosted on `ghcr.io` and exist under the `games`, `installers`, and `yolks` spaces. The following logic
is used when determining which space an image will live under:

- `games` — anything within the `games` folder in the repository. These are images built for running a specific game
  or type of game.
- `yolks` — these are more generic images that allow different types of games or scripts to run. They're generally just
  a specific version of software and allow different Eggs within Pterodactyl to switch out the underlying implementation. An
  example of this would be something like Java or Python which are used for running bots, Minecraft servers, etc.

All of these images are available for `linux/amd64` and `linux/arm64` versions, unless otherwise specified, to use
these images on an arm system, no modification to them or the tag is needed, they should just work.

## Contributing

When adding a new version to an existing image, such as `java v42`, you'd add it within a child folder of `java`, so
`java/42/Dockerfile` for example. Please also update the correct `.github/workflows` file to ensure that this new version
is tagged correctly.

## Available Images

### [Oses](/oses)

- [alpine](/oses/alpine)
    - `ghcr.io/darksaid98/yolks:alpine`
- [debian](/oses/debian)
    - `ghcr.io/darksaid98/yolks:debian`
- [ubuntu](/oses/ubuntu)
    - `ghcr.io/darksaid98/yolks:ubuntu`

### [Games](/games)

- [`fivem`](/games/fivem)
    - `ghcr.io/darksaid98/games:fivem`

### [GraalVM](/graakvm)

- [`17`](/graakvm/17)
    - `ghcr.io/darksaid98/graakvm:17`
- [`21`](/graakvm/21)
    - `ghcr.io/darksaid98/graakvm:21`
