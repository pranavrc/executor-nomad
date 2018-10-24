# Screwdriver Nomad Executor

> Nomad Executor plugin for Screwdriver

This is an executor for the Screwdriver continuous delivery solution that interacts with Nomad.

## Usage

```bash
npm install
npm publish
```

### Initialization
The class provides a couple options that are configurable in the instantiation of this Executor

| Parameter        | Type  | Default    | Description |
| :-------------   | :---- | :----------| :-----------|
| config        | Object | | Configuration Object |
| config.nomad | Object | {} | Nomad configuration Object |
| config.nomad.host | String | 'nomad.defaults' | The url for Nomad cluster (e.g. http://192.168.30.30:4646) |
| config.launchVersion | String | 'stable' | Launcher container version to use (stable) |
| config.prefix | String | '' | Prefix to container names ("") |
| config.nomad.resources.memory.high | Number | 4096 | Value for HIGH memory (in MB) |
| config.nomad.resources.cpu.high | Number | 600 | Value for HIGH CPU (in Mhz) |

### Methods

For more information on `start`, `stop`, and `stats` please see the [executor-base-class].

## Testing

```bash
npm test
```

## License

Code licensed under the BSD 3-Clause license. See LICENSE file for terms.

## Notes

[details](docs/index.md) about Nomad usage with Screwdriver can be found here.

