# Deploying to Home Assistant

## Quick Deploy (Push to Main)

Since you own the repository, you can push your changes directly:

```bash
# Stage your changes
git add vicohome_bridge/Dockerfile vicohome_bridge/config.yaml vicohome_bridge/BUILD.md vicohome_bridge/build.sh

# Commit with a descriptive message
git commit -m "Add AMD64 architecture support"

# Push to main branch
git push origin main
```

After pushing, Home Assistant will automatically pick up the changes when you:
1. Go to **Settings → Add-ons → Add-on Store**
2. Click **⋮ → Repositories**
3. If the repo is already added, click **⋮ → Reload** next to it
4. Or remove and re-add the repository URL: `https://github.com/KIWIDUDE564/vicohome-bridge-addon`

## Option 2: Create a Branch (Recommended for Testing)

If you want to test first or keep main stable:

```bash
# Create and switch to a new branch
git checkout -b add-amd64-support

# Stage your changes
git add vicohome_bridge/Dockerfile vicohome_bridge/config.yaml vicohome_bridge/BUILD.md vicohome_bridge/build.sh

# Commit
git commit -m "Add AMD64 architecture support"

# Push the branch
git push origin add-amd64-support
```

Then in Home Assistant, you can:
- Point to your branch by using: `https://github.com/KIWIDUDE564/vicohome-bridge-addon/tree/add-amd64-support`
- Or merge the branch to main when ready

## Installing in Home Assistant

1. **Add the repository** (if not already added):
   - Go to **Settings → Add-ons → Add-on Store**
   - Click **⋮ → Repositories**
   - Add: `https://github.com/KIWIDUDE564/vicohome-bridge-addon`
   - Click **Add**, then **Close**

2. **Install the add-on**:
   - Find **"Vicohome Bridge"** in the add-on list
   - Click **Install**
   - Wait for installation to complete

3. **Configure**:
   - Go to the **Configuration** tab
   - Fill in your Vicohome bridge account credentials
   - Save

4. **Start**:
   - Enable **Start on boot** and **Watchdog**
   - Click **Start**

## After Pushing Changes

If you've already installed the add-on and push updates:

1. Go to the add-on in Home Assistant
2. Click **Update** (if available) or **Uninstall → Reinstall**
3. The Supervisor will rebuild the image for your architecture (AMD64 or AArch64)

## Notes

- Home Assistant Supervisor automatically detects your system architecture
- With AMD64 support added, it will build the correct image for your system
- No need to manually specify architecture - the Supervisor handles it
- The Dockerfile now supports both `amd64` and `aarch64` automatically

