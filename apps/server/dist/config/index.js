"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
const zod_1 = require("zod");
// Load environment variables from root .env
dotenv_1.default.config({ path: path_1.default.resolve(__dirname, '../../../.env') });
const configSchema = zod_1.z.object({
    PORT: zod_1.z.coerce.number().default(3000),
    NODE_ENV: zod_1.z.enum(['development', 'production', 'test']).default('development'),
    DATABASE_URL: zod_1.z.string().url(),
    JWT_SECRET: zod_1.z.string().min(8),
    GITHUB_CLIENT_ID: zod_1.z.string().min(1),
    GITHUB_CLIENT_SECRET: zod_1.z.string().min(1),
    GITHUB_CALLBACK_URL: zod_1.z.string().url(),
    REDIS_URL: zod_1.z.string().url().default('redis://redis:6379'),
});
const parsed = configSchema.safeParse(process.env);
if (!parsed.success) {
    console.error('❌ Invalid environment variables:', JSON.stringify(parsed.error.format(), null, 2));
    process.exit(1);
}
exports.config = parsed.data;
