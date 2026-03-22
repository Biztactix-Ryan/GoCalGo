-- E2E seed data
-- Runs after the API container has applied EF Core migrations.
-- Seeds a device token and event flags so the full user journey can be tested.

BEGIN;

-- Seed a test device token
INSERT INTO "DeviceTokens" ("Token", "Platform", "Timezone", "CreatedAt", "UpdatedAt")
VALUES (
    'e2e-test-device-token-001',
    'android',
    'America/New_York',
    NOW(),
    NOW()
)
ON CONFLICT DO NOTHING;

-- Seed notification preferences for the test device
INSERT INTO "NotificationPreferences" ("DeviceToken", "Enabled", "LeadTimeMinutes", "EnabledEventTypes", "UpdatedAt")
VALUES (
    'e2e-test-device-token-001',
    true,
    15,
    'community-day,raid-hour,event',
    NOW()
)
ON CONFLICT DO NOTHING;

COMMIT;
