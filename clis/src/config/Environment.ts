import { Schema } from 'effect';

export const Environment = Schema.Literal('dev', 'staging', 'preprod', 'production');

export type Environment = typeof Environment.Type;
