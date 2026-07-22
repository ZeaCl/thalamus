import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import chalk from 'chalk';

const CONFIG_FILE = path.join(os.homedir(), '.config', 'zea', 'config.json');

async function load() {
  try { return JSON.parse(await fs.readFile(CONFIG_FILE, 'utf8')); }
  catch (e) { return {}; }
}

async function save(config) {
  await fs.mkdir(path.dirname(CONFIG_FILE), { recursive: true });
  await fs.writeFile(CONFIG_FILE, JSON.stringify(config, null, 2));
}

export function register(program) {
  const configCmd = program.command('config').description('Manage ZEA configuration');

  configCmd.command('set-env <env>')
    .description('Set standard environment profile (local or prod)')
    .action(async (envName) => {
      try {
        const config = await load();
        if (envName === 'local') {
          config.apiUrl = 'http://auth.zea.localhost';
          config.cerebelumUrl = 'http://cerebelum.zea.localhost';
          config.ventureUrl = 'http://venture.zea.localhost';
          config.sduiUrl = 'http://sdui.zea.localhost';
          config.appsUrl = 'http://apps.zea.localhost';
          config.gliaUrl = 'http://localhost:4002';
          config.gliaWsUrl = 'ws://localhost:4002/socket/websocket';
          config.sensorUrl = 'http://sensor.zea.localhost';
          console.log(chalk.green('✅ Environment set to LOCAL'));
        } else if (envName === 'prod') {
          config.apiUrl = 'https://auth.zea.cl';
          config.cerebelumUrl = 'https://cerebelum.zea.cl';
          config.ventureUrl = 'https://venture.zea.cl';
          config.sduiUrl = 'https://sdui.zea.cl';
          config.appsUrl = 'https://apps.zea.cl';
          config.gliaUrl = 'https://glia.zea.cl';
          config.gliaWsUrl = 'wss://glia.zea.cl/socket/websocket';
          config.sensorUrl = 'https://sensor.zea.cl';
          console.log(chalk.green('✅ Environment set to PROD'));
        } else {
          console.log(chalk.red('Unknown environment. Use "local" or "prod".'));
          return;
        }
        await save(config);
      } catch (e) {
        console.error('Error:', e.message);
      }
    });

  configCmd.command('set <key> <value>')
    .description('Set a configuration value')
    .action(async (key, value) => {
      try {
        const config = await load();
        config[key] = value;
        await save(config);
        console.log(chalk.green(`✅ ${key} = ${value}`));
      } catch (e) {
        console.error('Error:', e.message);
      }
    });

  configCmd.command('get <key>')
    .description('Get a configuration value')
    .action(async (key) => {
      try {
        const config = await load();
        if (config[key] !== undefined) {
          console.log(config[key]);
        } else {
          console.log(chalk.dim(`(not set: ${key})`));
        }
      } catch (e) {
        console.error('Error:', e.message);
      }
    });

  configCmd.command('list')
    .description('List all configuration values')
    .action(async () => {
      try {
        const config = await load();
        const keys = Object.keys(config);

        if (keys.length === 0) {
          console.log(chalk.dim('No configuration set.'));
          console.log(chalk.dim(`Config file: ${CONFIG_FILE}`));
          return;
        }

        console.log(chalk.cyan('ZEA Configuration:'));
        console.log(chalk.dim(`File: ${CONFIG_FILE}\n`));

        const masked = ['token', 'refreshToken', 'deepseek_key', 'deepseekKey'];

        for (const key of keys) {
          const val = masked.includes(key)
            ? '••••••••' + config[key].slice(-4)
            : config[key];
          console.log(`  ${chalk.yellow(key)}: ${val}`);
        }
      } catch (e) {
        console.error('Error:', e.message);
      }
    });

  configCmd.command('unset <key>')
    .description('Remove a configuration value')
    .action(async (key) => {
      try {
        const config = await load();
        delete config[key];
        await save(config);
        console.log(chalk.green(`✅ ${key} removed`));
      } catch (e) {
        console.error('Error:', e.message);
      }
    });

  configCmd.command('path')
    .description('Show config file path')
    .action(() => {
      console.log(CONFIG_FILE);
    });
}
