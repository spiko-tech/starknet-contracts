import * as Effect from "effect/Effect";
import { cli } from "./presentation/cli.js";
import { NodeContext, NodeRuntime } from "@effect/platform-node";

Effect.suspend(() => cli(process.argv)).pipe(
  Effect.provide([NodeContext.layer]),
  NodeRuntime.runMain
);
