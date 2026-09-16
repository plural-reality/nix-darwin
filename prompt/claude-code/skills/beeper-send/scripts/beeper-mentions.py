#!/usr/bin/env python3
"""Typed mention payload and readback checks; no network and no name-to-ID inference."""
import html
from html.parser import HTMLParser
import json
import re
import sys
from urllib.parse import unquote


def read_spec(spec):
    if not spec.startswith("@"):
        return spec
    with open(spec[1:], encoding="utf-8") as source:
        return source.read().rstrip("\n")


def read_mentions(spec):
    if not spec.startswith("@"):
        raise ValueError("--mentions requires @JSON-file")
    mentions = json.loads(read_spec(spec))
    if not isinstance(mentions, list) or not mentions:
        raise ValueError("--mentions requires a non-empty JSON array")
    for mention in mentions:
        if not isinstance(mention, dict) or set(mention) != {"id", "displayName", "start", "end"}:
            raise ValueError("each mention requires only id, displayName, start, end")
        if any(not isinstance(mention[key], str) or not mention[key] for key in ("id", "displayName")):
            raise ValueError("mention id and displayName must be non-empty strings")
        if any(type(mention[key]) is not int for key in ("start", "end")):
            raise ValueError("mention offsets must be UTF-16 integer positions")
        if mention["start"] < 0 or mention["end"] <= mention["start"]:
            raise ValueError("invalid mention range")
    return sorted(mentions, key=lambda value: (value["start"], value["end"], value["id"]))


def payload(chat_id, body_spec, reply_to, mention_spec):
    text = read_spec(body_spec)
    mentions = read_mentions(mention_spec)
    encoded = text.encode("utf-16-le")
    previous_end = 0
    for mention in mentions:
        start, end = mention["start"], mention["end"]
        if start < previous_end or end * 2 > len(encoded):
            raise ValueError("mention ranges overlap or exceed the text")
        if encoded[start * 2:end * 2].decode("utf-16-le") != "@" + mention["displayName"]:
            raise ValueError("mention range must exactly match @displayName")
        previous_end = end
    return {"chatId": chat_id, "text": text, "mentions": mentions,
            **({"replyToMessageId": reply_to} if reply_to else {})}


class VisibleMessage(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.ids = set()

    def handle_data(self, data):
        self.parts.append(data)

    def handle_starttag(self, tag, attrs):
        if tag == "br":
            self.parts.append("\n")
        if tag == "a":
            href = dict(attrs).get("href", "")
            if href.startswith("https://matrix.to/#/"):
                target = unquote(href[len("https://matrix.to/#/"):].split("?", 1)[0])
                if target.startswith("@"):
                    self.ids.add(target)


def raw_mention_ids(values):
    if not isinstance(values, list):
        return set()
    result = set()
    for value in values:
        if isinstance(value, str):
            result.add(value)
        elif isinstance(value, dict):
            for key in ("id", "userID", "userId", "participantID", "participantId"):
                if isinstance(value.get(key), str):
                    result.add(value[key])
                    break
    return result


def matches_message(item, expected):
    raw_text = item.get("text") or ""
    parser = VisibleMessage()
    # Parse only HTML-shaped Beeper content; ordinary '<literal>' remains literal.
    is_html = bool(re.search(r"<(?:a\s|br\s*/?>|p[ >])", raw_text, re.I))
    if is_html:
        parser.feed(raw_text)
    visible = "".join(parser.parts) if is_html else raw_text
    visible = visible.replace("\xa0", " ")
    ids = parser.ids | raw_mention_ids(item.get("mentions"))
    return (item.get("isSender") is True and not item.get("isDeleted", False)
            and visible == expected["text"].replace("\t", "  ")
            and str(item.get("linkedMessageID") or "") == expected.get("replyToMessageId", "")
            and ids == {mention["id"] for mention in expected["mentions"]})


def verified_id(items, expected, baseline, pending):
    baseline_index = next((index for index, item in enumerate(items) if str(item.get("id", "")) == baseline), None)
    new_items = items if not baseline else items[:baseline_index] if baseline_index is not None else []
    candidates = [item for item in items if pending and str(item.get("id", "")) == pending]
    candidates = candidates or new_items
    matches = [item for item in candidates if matches_message(item, expected)]
    if len(matches) != 1:
        raise ValueError("mention delivery ambiguous: exact text, IDs and reply readback required; do not resend")
    return str(matches[0]["id"])


def main(args):
    command = args[0]
    if command == "payload":
        print(json.dumps(payload(*args[1:]), ensure_ascii=False))
    elif command == "canonical":
        print(json.dumps(read_mentions(args[1]), sort_keys=True, separators=(",", ":")))
    elif command == "supported":
        with open(args[1], encoding="utf-8") as source:
            response = json.load(source)
        if response.get("support") != "supported":
            raise ValueError("CRM has not confirmed mention support; plain-text fallback is forbidden")
        with open(args[2], encoding="utf-8") as source:
            expected = json.load(source)
        if any(response.get(key) != expected.get(key) for key in ("chatId", "text", "replyToMessageId", "mentions")):
            raise ValueError("CRM preview changed the requested message or mention targets")
    elif command == "verify":
        with open(args[1], encoding="utf-8") as source:
            items = json.load(source).get("items", [])
        with open(args[2], encoding="utf-8") as source:
            expected = json.load(source)
        print(verified_id(items, expected, args[3], args[4]))
    else:
        raise ValueError("unknown mention helper command")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (ValueError, OSError, KeyError, UnicodeError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        sys.exit(1)
