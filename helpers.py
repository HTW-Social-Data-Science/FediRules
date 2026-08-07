import html
import math
import re
import time
import unicodedata
import warnings

import deepl
from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)

from config import DEEPL_API_KEY

TRANSLATOR = deepl.DeepLClient(DEEPL_API_KEY)


def translate(x, target_lang="EN-US"):
    try:
        if not isinstance(x, str) or not x.strip():
            return x
        for attempt in range(3):
            try:
                return TRANSLATOR.translate_text(x, target_lang=target_lang).text
            except deepl.DeepLException:
                if attempt == 2:
                    raise
                time.sleep(1 + attempt)
    except Exception as e:
        print(f"Error translating: {e}")
        return x


def clean_df(df, col_name):
    df = df.dropna(subset=[col_name])
    df = df[df[col_name].astype(str).str.strip() != ""]
    df.loc[:, col_name] = df[col_name].apply(remove_html_tags)
    return df


def clean_url(url):
    # Handle None, NaN, or non-string values
    if url is None:
        return None
    if isinstance(url, float) and math.isnan(url):
        return None
    if not isinstance(url, str):
        return None

    # Remove protocol
    if url.startswith("https://"):
        url = url[len("https://"):]
    elif url.startswith("http://"):
        url = url[len("http://"):]

    # Remove /notice/... suffix
    if "/notice/" in url:
        url = url.split("/notice/")[0]

    # Remove trailing slash
    url = url.rstrip("/")

    return url


def remove_html_tags(html_content):
    if not isinstance(html_content, str):
        return ""
    soup = BeautifulSoup(html_content, "html.parser")
    text = soup.get_text(strip=True)
    return html.unescape(text)


def remove_special_characters(text):
    if not isinstance(text, str):
        return ""

    # remove control characters (categories starting with 'C')
    cleaned_chars = []
    for ch in text:
        if unicodedata.category(ch)[0] == "C":
            continue  # skip control chars
        cleaned_chars.append(ch)
    text = "".join(cleaned_chars)

    # normalize whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


def replace_user_handles(text):
    """
    Replace @username and @username@server with @USER.
    """
    pattern = r'@[A-Za-z0-9_\-\.]+(?:@[A-Za-z0-9_\-\.]+)?'
    return re.sub(pattern, '@USER', text)


def clean_toots(text):
    text = remove_html_tags(text)
    text = replace_user_handles(text)
    return remove_special_characters(text)
