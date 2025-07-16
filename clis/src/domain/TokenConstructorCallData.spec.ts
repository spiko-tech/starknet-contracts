import { it, expect } from "@effect/vitest";
import { TokenConstructorCallData } from "./TokenConstructorCallData";
import { Effect } from "effect";

it.effect("should format the call data correctly", () =>
  Effect.gen(function* () {
    const callData = new TokenConstructorCallData({
      owner:
        "0x05E05d047FabDA178afce281A5107016a6997E5123d505A2296e375374f9C814",
      name: "Spiko US T-Bills Money Market Fund",
      symbol: "USTBL",
      decimals: 5,
    });

    const result = callData.toString();

    expect(result).toStrictEqual(
      "0x05E05d047FabDA178afce281A5107016a6997E5123d505A2296e375374f9C814 0x01 0x5370696b6f2054000000000000000000000000000000000000000000000000 0x756e64 0x03 0x00 0x555354424c 0x05 0x05"
    );
  })
);
