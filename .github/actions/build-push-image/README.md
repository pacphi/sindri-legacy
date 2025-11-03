# Build and Push Docker Image Action

Composite action for building Docker images and pushing to Fly.io registry.

## Usage

```yaml
- name: Build and push image
  uses: ./.github/actions/build-push-image
  with:
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    tag: "pr-123-a1b2c3d"
    registry-app: "sindri-registry"
```

## Inputs

| Input           | Description             | Required | Default           |
| --------------- | ----------------------- | -------- | ----------------- |
| `fly-api-token` | Fly.io API token        | Yes      | N/A               |
| `tag`           | Image tag               | Yes      | N/A               |
| `registry-app`  | Registry app name       | No       | `sindri-registry` |
| `dockerfile`    | Path to Dockerfile      | No       | `Dockerfile`      |
| `build-context` | Build context directory | No       | `.`               |

## Outputs

| Output      | Description                                      |
| ----------- | ------------------------------------------------ |
| `image-url` | Full image URL (e.g., `registry.fly.io/app:tag`) |
| `image-tag` | Image tag used                                   |

## Examples

See `.github/workflows/build-image.yml` for a complete example.
