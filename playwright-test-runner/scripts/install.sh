#!/bin/bash
# Playwright Test Runner — Installation Script
set -e

echo "🎭 Installing Playwright Test Runner..."

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js is required. Install it first:"
  echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
  echo "   sudo apt-get install -y nodejs"
  exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "❌ Node.js 18+ required (found: $(node -v))"
  exit 1
fi

echo "✅ Node.js $(node -v) detected"

# Install Playwright
echo "📦 Installing @playwright/test..."
npm init -y 2>/dev/null || true
npm install @playwright/test

# Install browsers
echo "🌐 Installing browsers (Chromium, Firefox, WebKit)..."
npx playwright install

# Install system dependencies (Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "📦 Installing system dependencies..."
  npx playwright install-deps 2>/dev/null || {
    echo "⚠️  Could not auto-install system deps. Run with sudo:"
    echo "   sudo npx playwright install-deps"
  }
fi

# Create default directories
mkdir -p tests screenshots playwright-report logs

# Create example test
if [ ! -f tests/example.spec.js ]; then
  cat > tests/example.spec.js << 'TESTEOF'
const { test, expect } = require('@playwright/test');

test('homepage loads successfully', async ({ page }) => {
  await page.goto('https://example.com');
  await expect(page).toHaveTitle(/Example/);
  console.log('✅ Homepage loaded successfully');
});

test('page has expected content', async ({ page }) => {
  await page.goto('https://example.com');
  const heading = page.locator('h1');
  await expect(heading).toHaveText('Example Domain');
});
TESTEOF
  echo "✅ Created example test: tests/example.spec.js"
fi

# Create default config if not exists
if [ ! -f playwright.config.js ]; then
  cat > playwright.config.js << 'CFGEOF'
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 1,
  workers: 2,
  use: {
    headless: true,
    viewport: { width: 1920, height: 1080 },
    screenshot: 'on-failure',
    trace: 'retain-on-failure',
  },
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
  ],
});
CFGEOF
  echo "✅ Created default config: playwright.config.js"
fi

echo ""
echo "🎭 Playwright Test Runner installed successfully!"
echo ""
echo "Quick start:"
echo "  bash scripts/run.sh screenshot --url https://example.com --output test.png"
echo "  bash scripts/run.sh test --file tests/example.spec.js"
echo "  bash scripts/run.sh healthcheck --url https://example.com"
