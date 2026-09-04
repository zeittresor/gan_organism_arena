# Testing — 1.0.0-alpha22 (2026-09-04)

## Native evidence supplied by the user

Alpha21 completed installation, parsing, all self-tests and smoke startup/shutdown. The supplied 2026-09-04 logs contain no ERROR/WARNING entries. They show periods of substantial movement/contact cost and population decline; screenshots do not by themselves measure travel paths. The movement report motivated the new navigation tests.

## Current checks

- **11,457 named production-source checks** plus the morphology/genome/language core test pass: navigation 43, posture 868, support 857, locomotion 3,371, interaction 5,443, ecology 51, surface 71, lifecycle 115, biology 617, experiment 21.
- Navigation tests run real decision and movement code for three body plans approaching bottom food. They verify head-local feeding, physical travel, persistent exploration, failed-target cooldown, developmental-stage food eligibility, perception range, compatible partner approach and emergency priority.
- Active-world coupling, gestation, birth, development, energy bounds and reserved capacity integration passes with one offspring.
- OBJ export still passes all four view transitions with accurate vertices/faces and no graphics transform readback. Fifteen Python adapter tests pass.
- 47 GDScripts pass grammar parsing and are registered in the native parse/package checks. All 55 existing settings/actions retain labels and tooltips in three languages. The new selection status and partner-seeking label are localized too.
- Fresh ZIP extraction, CRC, payload SHA-256 and file count are verified before delivery.

## Limits

These checks execute production GDScript through a Python translation harness with substitute engine objects. They are not native Godot execution. Windows/GPU performance, visuals and native Alpha22 installation still need confirmation; the installer retains every native gate. The source world comparison is recorded in WORLD_NAVIGATION_CHECK.txt. It measures one seed and short runs, not a general survival or reproduction rate.

Navigation uses local sensing and finite retries, not globally complete pathfinding. Anatomy, maturity, respiration, energy and existing flight requirements still constrain movement. Evolutionary outcomes are not guaranteed or forced.
