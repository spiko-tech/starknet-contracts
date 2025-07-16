import { byteArray, CallData } from "starknet";

export class StarknetFormatter {
  static removeHexPrefix(hex: string) {
    let hexTrim = hex.replace(/^0x/, "");
    if (hexTrim.length % 2 === 1) {
      hexTrim = "0" + hexTrim;
    }
    return hexTrim;
  }

  static addHexPrefix(hex: string) {
    return `0x${this.removeHexPrefix(hex)}`;
  }

  static formatAsByteArray(value: string) {
    return CallData.compile(byteArray.byteArrayFromString(value))
      .toString()
      .split(",")
      .map((hex) => this.addHexPrefix(Number(hex).toString(16)));
  }
}
