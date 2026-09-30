#!/usr/bin/env python3
"""
export_st.py - Generate readable Structured Text files from a CODESYS PLCopen XML export.

The CODESYS project (.project) stays the source of truth. This script only produces
a read-only, human-readable mirror of it, one .st file per object, laid out like
the folder tree of the project, so that the code can be read and reviewed on GitHub.

Usage:
    python tools/export_st.py plc/Automatic_ScrewDriver_Line.xml src

Every run deletes the previously generated .st files in the output folder before
writing the new ones, so that objects removed from the project also disappear here.

Requires Python 3.8+ and the standard library only.
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PLCOPEN_NS = "http://www.plcopen.org/xml/tc6_0200"
XHTML_NS = "http://www.w3.org/1999/xhtml"
CS = "http://www.3s-software.com/plcopenxml/"   # CODESYS-specific addData prefix

SECTION_KEYWORDS = {
    "inputVars": "VAR_INPUT",
    "outputVars": "VAR_OUTPUT",
    "inOutVars": "VAR_IN_OUT",
    "localVars": "VAR",
    "tempVars": "VAR_TEMP",
    "externalVars": "VAR_EXTERNAL",
    "globalVars": "VAR_GLOBAL",
}
SECTION_ORDER = ["inputVars", "outputVars", "inOutVars", "localVars", "tempVars", "externalVars"]

POU_KEYWORDS = {
    "program": ("PROGRAM", "END_PROGRAM"),
    "functionBlock": ("FUNCTION_BLOCK", "END_FUNCTION_BLOCK"),
    "function": ("FUNCTION", "END_FUNCTION"),
}


# --------------------------------------------------------------------------- helpers

def strip_namespaces(root):
    """Remove XML namespaces so that tags can be matched by their local name."""
    for el in root.iter():
        if isinstance(el.tag, str) and "}" in el.tag:
            el.tag = el.tag.split("}", 1)[1]
    return root


def child(el, tag):
    return el.find(tag) if el is not None else None


def addata(el, suffix):
    """Return the CODESYS addData <data> element whose name ends with `suffix`."""
    if el is None:
        return None
    for data in el.iter("data"):
        if data.get("name", "") == CS + suffix:
            return data
    return None


def direct_addata(el, suffix):
    """Like addata(), but only looks at the element's own <addData>, not its descendants."""
    ad = child(el, "addData")
    if ad is None:
        return None
    for data in ad.findall("data"):
        if data.get("name", "") == CS + suffix:
            return data
    return None


def doc_text(el):
    """Return the documentation comment attached to an element, or ''."""
    doc = child(el, "documentation")
    if doc is None:
        return ""
    xh = child(doc, "xhtml")
    return (xh.text or "").strip() if xh is not None else ""


def st_body(el):
    """Return the ST implementation text of a POU or method body, or ''."""
    body = child(el, "body")
    st = child(body, "ST")
    xh = child(st, "xhtml")
    return (xh.text or "").rstrip() if xh is not None else ""


def attributes(el):
    """Return the CODESYS pragmas {attribute '...'} declared directly on an element."""
    data = direct_addata(el, "attributes")
    if data is None:
        return []
    lines = []
    for attr in data.iter("Attribute"):
        name, value = attr.get("Name"), attr.get("Value", "")
        if name == "abstract":      # already rendered as the ABSTRACT keyword
            continue
        lines.append("{attribute '%s'%s}" % (name, " := '%s'" % value if value else ""))
    return lines


# --------------------------------------------------------------------------- types and values

def render_type(type_el):
    """Render a <type> or <baseType> element as IEC 61131-3 text."""
    if type_el is None or len(type_el) == 0:
        return "?"
    t = type_el[0]
    tag = t.tag
    if tag == "derived":
        return t.get("name")
    if tag in ("string", "wstring"):
        length = t.get("length")
        return tag.upper() + ("(%s)" % length if length else "")
    if tag == "array":
        dims = ", ".join("%s..%s" % (d.get("lower"), d.get("upper")) for d in t.findall("dimension"))
        return "ARRAY[%s] OF %s" % (dims, render_type(child(t, "baseType")))
    if tag == "pointer":
        return "POINTER TO " + render_type(child(t, "baseType"))
    if tag == "reference":
        return "REFERENCE TO " + render_type(child(t, "baseType"))
    return tag.upper()          # elementary types: BOOL, INT, REAL, TIME, DT, ...


def render_value(v):
    """Render an <initialValue> content element."""
    if v is None or len(v) == 0:
        return ""
    inner = v[0]
    if inner.tag == "simpleValue":
        return inner.get("value", "")
    if inner.tag == "arrayValue":
        items = []
        for val in inner.findall("value"):
            text = render_value(val)
            rep = val.get("repetitionValue")
            items.append("%s(%s)" % (rep, text) if rep else text)
        return "[" + ", ".join(items) + "]"
    if inner.tag == "structValue":
        members = ["%s := %s" % (val.get("member"), render_value(val)) for val in inner.findall("value")]
        return "(" + ", ".join(members) + ")"
    return ""


def render_variable(var, indent="\t"):
    lines = []
    doc = doc_text(var)
    doc_lines = [l.strip() for l in doc.splitlines() if l.strip()]
    for a in attributes(var):
        lines.append(indent + a)
    decl = "%s : %s" % (var.get("name"), render_type(child(var, "type")))
    init_el = child(var, "initialValue")
    init = render_value(init_el)
    if init and len(init) > 100 and init_el[0].tag == "arrayValue":
        # Long array initialisers (e.g. a recipe table): one element per line.
        items = [render_value(v) for v in init_el[0].findall("value")]
        decl += " := [\n" + ",\n".join(indent + "\t" + i for i in items) + "\n" + indent + "]"
    elif init:
        decl += " := " + init
    decl += ";"
    if len(doc_lines) == 1:
        lines.append("%s%s   // %s" % (indent, decl, doc_lines[0]))
    else:
        lines.extend(indent + "// " + l for l in doc_lines)
        lines.append(indent + decl)
    return lines


def render_sections(interface_el):
    """Render every VAR_... block of an <interface> element."""
    out = []
    if interface_el is None:
        return out
    for key in SECTION_ORDER:
        for section in interface_el.findall(key):
            variables = section.findall("variable")
            if not variables:
                continue
            kw = SECTION_KEYWORDS[key]
            if section.get("constant") == "true":
                kw += " CONSTANT"
            if section.get("retain") == "true":
                kw += " RETAIN"
            if section.get("persistent") == "true":
                kw += " PERSISTENT"
            out.append(kw)
            for var in variables:
                out.extend(render_variable(var))
            out.append("END_VAR")
    return out


def access_modifiers(el):
    data = direct_addata(el, "accessmodifiers")
    if data is None:
        data = addata(child(el, "interface"), "accessmodifiers")
    if data is None:
        return ""
    mods = data.find("AccessModifiers")
    if mods is None:
        return ""
    words = []
    for key in ("Private", "Protected", "Internal", "Public"):
        if mods.get(key) == "true":
            words.append(key.upper())
    for key in ("Abstract", "Final"):
        if mods.get(key) == "true":
            words.append(key.upper())
    return " ".join(words)


# --------------------------------------------------------------------------- objects

def render_method(method):
    iface = child(method, "interface")
    ret = child(iface, "returnType")
    mods = access_modifiers(method)
    header = "METHOD %s%s" % (mods + " " if mods else "", method.get("name"))
    if ret is not None and len(ret):
        header += " : " + render_type(ret)
    lines = attributes(method) + [header] + render_sections(iface)
    body = st_body(method)
    if body:
        lines += ["", body]
    lines.append("END_METHOD")
    return lines


def render_pou(pou):
    kind = pou.get("pouType")
    begin, end = POU_KEYWORDS.get(kind, (kind.upper(), "END_" + kind.upper()))
    iface = child(pou, "interface")

    header = begin
    mods = access_modifiers(iface) if iface is not None else ""
    if mods:
        header += " " + mods
    header += " " + pou.get("name")
    ret = child(iface, "returnType")
    if ret is not None and len(ret):
        header += " : " + render_type(ret)
    inherit = addata(iface, "pouinheritance")
    if inherit is not None:
        ext = [e.text for e in inherit.iter("Extends")]
        imp = [i.text for i in inherit.iter("Implements")]
        if ext:
            header += " EXTENDS " + ", ".join(ext)
        if imp:
            header += " IMPLEMENTS " + ", ".join(imp)

    lines = attributes(iface) + [header] + render_sections(iface)
    body = st_body(pou)
    if body:
        lines += ["", body]

    pou_addata = child(pou, "addData")
    for data in (pou_addata.findall("data") if pou_addata is not None else []):
        if data.get("name") == CS + "method":
            for method in data.findall("Method"):
                lines += ["", ""] + render_method(method)

    lines += ["", end]
    return lines


def render_interface(itf):
    header = "INTERFACE " + itf.get("name")
    ext = [e.text for e in itf.iter("Extends")]
    if ext:
        header += " EXTENDS " + ", ".join(ext)
    lines = [header]
    methods = child(itf, "Methods")
    for method in (methods if methods is not None else []):
        lines += [""] + render_method(method)
    lines += ["", "END_INTERFACE"]
    return lines


def render_datatype(dt):
    lines = attributes(dt) + ["TYPE %s :" % dt.get("name")]
    base = child(dt, "baseType")
    inner = base[0] if base is not None and len(base) else None
    if inner is not None and inner.tag == "struct":
        lines.append("STRUCT")
        for var in inner.findall("variable"):
            lines += render_variable(var)
        lines.append("END_STRUCT")
    elif inner is not None and inner.tag == "enum":
        values = child(inner, "values").findall("value")
        items = []
        for i, v in enumerate(values):
            text = "\t" + v.get("name")
            if v.get("value") not in (None, ""):
                text += " := " + v.get("value")
            items.append(text + ("," if i < len(values) - 1 else ""))
        lines += ["("] + items + [");"]
    else:
        lines[-1] = "TYPE %s : %s;" % (dt.get("name"), render_type(base))
    lines.append("END_TYPE")
    return lines


def render_gvl(gvl):
    lines = attributes(gvl)
    kw = "VAR_GLOBAL"
    if gvl.get("constant") == "true":
        kw += " CONSTANT"
    if gvl.get("retain") == "true":
        kw += " RETAIN"
    lines.append(kw)
    for var in gvl.findall("variable"):
        lines += render_variable(var)
    lines.append("END_VAR")
    return lines


# --------------------------------------------------------------------------- project tree

def folder_map(root):
    """Map object names to their folder path, from the CODESYS project structure."""
    mapping = {}
    ps = root.find(".//ProjectStructure")
    if ps is None:
        return mapping

    def walk(node, path):
        for el in node:
            if el.tag == "Folder":
                walk(el, path + [el.get("Name")])
            elif el.tag == "Object":
                mapping.setdefault(el.get("Name"), path)
                walk(el, path)          # objects such as Device/Application contain folders

    walk(ps, [])
    return mapping


def collect(root):
    """Yield (name, lines) for every code object of the export."""
    for data in root.iter("data"):
        name = data.get("name", "")
        if name == CS + "pou":
            for pou in data.findall("pou"):
                yield pou.get("name"), render_pou(pou)
        elif name == CS + "interface":
            for itf in data.findall("Interface"):
                yield itf.get("name"), render_interface(itf)
        elif name == CS + "datatype":
            for dt in data.findall("dataType"):
                yield dt.get("name"), render_datatype(dt)
    for gvl in root.iter("globalVars"):
        if gvl.get("name"):
            yield gvl.get("name"), render_gvl(gvl)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("xml", type=Path, help="PLCopen XML export of the CODESYS project")
    parser.add_argument("out", type=Path, help="output folder, e.g. src")
    args = parser.parse_args()

    root = strip_namespaces(ET.parse(args.xml).getroot())
    folders = folder_map(root)

    # Clean previously generated files, so that deleted objects disappear.
    if args.out.exists():
        for f in args.out.rglob("*.st"):
            f.unlink()
        for d in sorted((p for p in args.out.rglob("*") if p.is_dir()), key=lambda p: len(p.parts), reverse=True):
            if not any(d.iterdir()):
                d.rmdir()

    header = [
        "// Generated from %s by tools/export_st.py - do not edit." % args.xml.name,
        "// The CODESYS project is the source of truth.",
        "",
    ]
    count = 0
    for name, lines in collect(root):
        path = args.out.joinpath(*folders.get(name, []), name + ".st")
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(header + lines) + "\n")
        count += 1

    print("%d files written to %s" % (count, args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
