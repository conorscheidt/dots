# Extension preferences

Home Manager exposes these files at `~/.config/brave/extension-settings/`.
Import the matching JSON through each extension's settings page. A Darwin
switch installs the files; it does not import them into browser storage.

- Dark Reader: Settings → Advanced → Import settings.
- Tweaks for YouTube: Options → Import/export.
- Canvas Refined / compatible Better Canvas imports: Import theme/settings.
- SponsorBlock: Options → import configuration.

The Dark Reader theme object is complete because its importer merges nested
theme settings shallowly. Installation metadata is omitted. SponsorBlock is a
partial configuration: account identifiers, payments, permissions, counters
and migration state remain owned by the extension and are not exported here.

These snapshots were captured against Dark Reader 4.9.134, Tweaks for YouTube
3.94.0, Canvas Refined 7.2.0 and SponsorBlock 6.1.6. Review an extension's import
behavior before reusing a snapshot across incompatible updates.
