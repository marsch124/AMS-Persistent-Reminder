#!/usr/bin/env python3
"""Builds the helper shortcut "AMS Persistent Reminder Helper" and signs it so anyone can add it.

What it does on the iPhone: Get My Shortcuts → one name per line → URL-encode →
opens amsreminder://shortcuts?names=<the list>, and the app keeps the list for its picker.
Run: python3 Tools/make-helper-shortcut.py   (writes App/Resources/AMS Persistent Reminder Helper.shortcut)
"""
import plistlib, subprocess, uuid, pathlib, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "App/Resources/AMS Persistent Reminder Helper.shortcut"
U = [str(uuid.uuid4()).upper() for _ in range(5)]
OBJ = "￼"

def out(i, name):
    return {"OutputName": name, "OutputUUID": U[i], "Type": "ActionOutput"}

def token_string(prefix, i, name):
    return {"Value": {"string": prefix + OBJ, "attachmentsByRange": {f"{{{len(prefix)}, 1}}": out(i, name)}},
            "WFSerializationType": "WFTextTokenString"}

def attachment(i, name):
    return {"Value": out(i, name), "WFSerializationType": "WFTextTokenAttachment"}

actions = [
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getmyworkflows",
     "WFWorkflowActionParameters": {"UUID": U[0]}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.text.combine",
     "WFWorkflowActionParameters": {"UUID": U[1], "WFTextSeparator": "New Lines", "text": attachment(0, "My Shortcuts")}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.urlencode",
     "WFWorkflowActionParameters": {"UUID": U[2], "WFInput": token_string("", 1, "Combined Text")}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.gettext",
     "WFWorkflowActionParameters": {"UUID": U[3], "WFTextActionText": token_string("amsreminder://shortcuts?names=", 2, "URL Encoded Text")}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
     "WFWorkflowActionParameters": {"UUID": U[4], "WFInput": attachment(3, "Text"), "Show-WFInput": True}},
]
wf = {
    "WFWorkflowClientVersion": "2607.0.4",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4251333119, "WFWorkflowIconGlyphNumber": 59446},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowTypes": [],
    "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowHasOutputFallback": False,
    "WFWorkflowHasShortcutInputVariables": False,
    "WFQuickActionSurfaces": [],
    "WFWorkflowActions": actions,
}
with tempfile.TemporaryDirectory() as tmp:
    raw = pathlib.Path(tmp) / "AMS Persistent Reminder Helper.shortcut"
    raw.write_bytes(plistlib.dumps(wf, fmt=plistlib.FMT_BINARY))
    subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", str(raw), "--output", str(OUT)], check=True)
print("signed:", OUT, OUT.stat().st_size, "bytes")
