import { Command, Options } from '@effect/cli';
import { pipe } from 'effect';
import { craftTokenContractDeployment } from '../application/craftTokenContractDeployment.js';
import { Environment } from '../config/Environment.js';

const command = Command.make('starknet-contracts-cli').pipe(
  Command.withDescription('Starknet contracts CLI'),
  Command.withSubcommands([
    pipe(
      Command.make('craft-token-contract-deployment', {
        address: Options.text('address').pipe(
          Options.withPseudoName('<ADDRESS>'),
          Options.withDescription('Address of the account to use')
        ),
        environment: Options.text('environment').pipe(
          Options.withSchema(Environment),
          Options.withPseudoName('<ENVIRONMENT>'),
          Options.withDescription('Environment to use')
        ),
      }),
      Command.withDescription('Craft token contract deployment.'),
      Command.withHandler(craftTokenContractDeployment)
    ),
  ])
);

export const cli = pipe(
  command,
  Command.run({
    name: 'Starknet Contracts CLI',
    version: '0.0.1',
  })
);
