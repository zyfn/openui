# Approved native screenshots

This directory is intentionally empty of PNGs until the iPhone captures have
passed UI Lab review and user visual acceptance. The XCUITest suite always attaches actual native images
to its xcresult bundle. When a matching approved PNG is present here, it also
compares normalized RGBA pixels with a bounded tolerance.

Do not automatically record or overwrite a baseline after a failing test.
Review layout, text wrapping, alignment, clipping and control states first.
Record the simulator model, iOS runtime, locale and content-size category with
any accepted baseline set. A new device/runtime can require a separate set.
