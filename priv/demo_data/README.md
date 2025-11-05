# Demo Data JSON Files

This directory contains pre-generated JSON datasets for faster application startup.

## Files

- `small.json` - Small dataset (~500 records)
- `medium.json` - Medium dataset (~2,500 records)
- `large.json` - Large dataset (~35,000 records)
- `huge.json` - Huge dataset (~860,000 records)

## Generating JSON Files

To generate or regenerate the JSON files, run:

```bash
# Generate all datasets
mix demo.generate_json

# Generate only a specific dataset
mix demo.generate_json --only small
mix demo.generate_json --only medium
mix demo.generate_json --only large
mix demo.generate_json --only huge
```

## Loading Behavior

When the application starts:
1. It checks if all 4 JSON files exist in this directory
2. If they exist, it loads them (takes ~10-30 seconds)
3. If they don't exist, it generates them from scratch (takes ~5-10 minutes)

## File Size

- small.json: ~500 KB
- medium.json: ~2 MB
- large.json: ~20 MB
- huge.json: ~500 MB

Total: ~520-550 MB
