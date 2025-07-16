import { Effect } from 'effect';
import { CONFIGURATIONS } from '../config/CONFIGURATIONS.js';
import { TokenConstructorCallData } from '../domain/TokenConstructorCallData.js';
import { Environment } from '../config/Environment.js';

export const craftTokenContractDeployment = ({ address, environment }: { address: string; environment: Environment }) =>
  Effect.gen(function* () {
    const configuration = CONFIGURATIONS[environment];

    for (const token of configuration.tokens) {
      const tokenConstructorCallData = new TokenConstructorCallData({
        owner: address,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
      });

      yield* Effect.logInfo(`Token Constructor Call Data for ${token.name}:`);
      yield* Effect.logInfo(tokenConstructorCallData.format());
    }
  });
