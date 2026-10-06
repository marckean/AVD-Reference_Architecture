"""Checks that the Deploy to Azure template and its portal wizard agree.

Every output of deploy/createUiDefinition.json must be a parameter of deploy/azuredeploy.json, and every
template parameter without a default value must be supplied by the wizard. Also checks that both files
declare the expected schemas, and that every OptionsGroup or DropDown default value is one of its labels.
Standard library only.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "deploy" / "azuredeploy.json"
UI = ROOT / "deploy" / "createUiDefinition.json"

if not TEMPLATE.exists() or not UI.exists():
    print("No deploy template or wizard found - nothing to check.")
    sys.exit(0)

template = json.loads(TEMPLATE.read_text(encoding="utf-8-sig"))
ui = json.loads(UI.read_text(encoding="utf-8-sig"))
problems = []

if "deploymentTemplate.json" not in template.get("$schema", ""):
    problems.append(f"azuredeploy.json has an unexpected $schema: {template.get('$schema')}")
if "CreateUIDefinition" not in ui.get("$schema", ""):
    problems.append(f"createUiDefinition.json has an unexpected $schema: {ui.get('$schema')}")
if ui.get("handler") != "Microsoft.Azure.CreateUIDef":
    problems.append("createUiDefinition.json handler must be Microsoft.Azure.CreateUIDef")

params = template.get("parameters", {})
outputs = ui.get("parameters", {}).get("outputs", {})

for name in outputs:
    if name not in params:
        problems.append(f"Wizard output '{name}' isn't a template parameter")

for name, spec in params.items():
    if "defaultValue" not in spec and name not in outputs:
        problems.append(f"Template parameter '{name}' has no default and isn't supplied by the wizard")


def check_defaults(node):
    """Learn: an OptionsGroup or DropDown default value must be a label present in constraints.allowedValues."""
    if isinstance(node, dict):
        if node.get("type") in ("Microsoft.Common.OptionsGroup", "Microsoft.Common.DropDown") and "defaultValue" in node:
            labels = [item.get("label") for item in node.get("constraints", {}).get("allowedValues", [])]
            if node["defaultValue"] not in labels:
                problems.append(f"Wizard control '{node.get('name')}' has default '{node['defaultValue']}', which isn't one of its labels")
        for value in node.values():
            check_defaults(value)
    elif isinstance(node, list):
        for value in node:
            check_defaults(value)


check_defaults(ui)

if problems:
    print("\n".join(problems))
    sys.exit(1)

print(f"Template and wizard agree: {len(outputs)} wizard outputs, {len(params)} template parameters.")
