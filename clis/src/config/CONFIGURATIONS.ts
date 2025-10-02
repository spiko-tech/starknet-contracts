import { Environment } from './Environment.js';

export type Configuration = {
  tokens: Array<{
    name: string;
    symbol: string;
    decimals: number;
  }>;
};

export const CONFIGURATIONS: Record<Environment, Configuration> = {
  dev: {
    tokens: [
      { name: 'Dev EUTBL', symbol: 'EUTBL', decimals: 5 },
      { name: 'Dev USTBL', symbol: 'USTBL', decimals: 5 },
      { name: 'Dev eurUSTBL', symbol: 'eurUSTBL', decimals: 5 },
      { name: 'Dev UKTBL', symbol: 'UKTBL', decimals: 5 },
      { name: 'Dev SPKCC', symbol: 'SPKCC', decimals: 5 },
      { name: 'Dev eurSPKCC', symbol: 'eurSPKCC', decimals: 5 },
    ],
  },
  staging: {
    tokens: [
      { name: 'Staging EUTBL', symbol: 'EUTBL', decimals: 5 },
      { name: 'Staging USTBL', symbol: 'USTBL', decimals: 5 },
      { name: 'Staging eurUSTBL', symbol: 'eurUSTBL', decimals: 5 },
      { name: 'Staging UKTBL', symbol: 'UKTBL', decimals: 5 },
      { name: 'Staging SPKCC', symbol: 'SPKCC', decimals: 5 },
      { name: 'Staging eurSPKCC', symbol: 'eurSPKCC', decimals: 5 },
    ],
  },
  preprod: {
    tokens: [
      { name: 'Preprod EUTBL', symbol: 'EUTBL', decimals: 5 },
      { name: 'Preprod USTBL', symbol: 'USTBL', decimals: 5 },
      { name: 'Preprod eurUSTBL', symbol: 'eurUSTBL', decimals: 5 },
      { name: 'Preprod UKTBL', symbol: 'UKTBL', decimals: 5 },
      { name: 'Preprod SPKCC', symbol: 'SPKCC', decimals: 5 },
      { name: 'Preprod eurSPKCC', symbol: 'eurSPKCC', decimals: 5 },
    ],
  },
  production: {
    tokens: [
      { name: 'Spiko UK T-Bills Money Market Fund', symbol: 'UKTBL', decimals: 5 },
      { name: 'Spiko UK T-Bills Money Market Fund (EUR)', symbol: 'eurUKTBL', decimals: 5 },
      { name: 'Spiko Digital Assets Cash and Carry Fund', symbol: 'SPKCC', decimals: 5 },
      { name: 'Spiko Digital Assets Cash and Carry Fund (EUR hedged)', symbol: 'eurSPKCC', decimals: 5 },
    ],
  },
};
