"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.WebhookConnector = exports.OpenAIConnector = exports.EchoConnector = exports.BaseConnector = void 0;
/**
 * Barrel export for all connectors.
 * Importing this module registers all built-in connectors
 * into the singleton ConnectorRegistry.
 */
var base_1 = require("./base");
Object.defineProperty(exports, "BaseConnector", { enumerable: true, get: function () { return base_1.BaseConnector; } });
var echo_1 = require("./echo");
Object.defineProperty(exports, "EchoConnector", { enumerable: true, get: function () { return echo_1.EchoConnector; } });
var openai_1 = require("./openai");
Object.defineProperty(exports, "OpenAIConnector", { enumerable: true, get: function () { return openai_1.OpenAIConnector; } });
var webhook_1 = require("./webhook");
Object.defineProperty(exports, "WebhookConnector", { enumerable: true, get: function () { return webhook_1.WebhookConnector; } });
__exportStar(require("./errors"), exports);
