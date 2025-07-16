import { Schema } from 'effect';
import { StarknetFormatter } from './StarknetFormatter.js';

export class TokenConstructorCallData extends Schema.Class<TokenConstructorCallData>('TokenConstructorCallData')({
  owner: Schema.String,
  name: Schema.String,
  symbol: Schema.String,
  decimals: Schema.Number,
}) {
  format = () => {
    const formattedName = StarknetFormatter.formatAsByteArray(this.name);
    const formattedSymbol = StarknetFormatter.formatAsByteArray(this.symbol);
    const formattedDecimals = StarknetFormatter.addHexPrefix(this.decimals.toString());

    return `${this.owner} ${formattedName.join(' ')} ${formattedSymbol.join(' ')} ${formattedDecimals}`;
  };
}
