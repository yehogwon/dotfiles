#!/usr/bin/python3

import requests
from urllib.parse import urlparse, urlunparse
from bs4 import BeautifulSoup
from tqdm import tqdm
from argparse import ArgumentParser
from multiprocessing import Pool

def read_file(file_path):
    """Read a file and return its lines."""
    with open(file_path, 'r') as f:
        return [line.strip() for line in f.readlines()]

def proc_list(l): 
    return list(filter(lambda x: x is not None and x != '', set(l)))

def get_hrefs(url): 
    """Get all hrefs from a given URL."""
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "html.parser")
        return [link.get("href") for link in soup.find_all("a") if link.get("href")]
    except Exception as e:
        return []

def _switch_hyphens_underscores(s): 
    if '-' in s and '_' in s:
        return None
    if '-' in s: 
        return s.replace('-', '_')
    if '_' in s:
        return s.replace('_', '-')
    return None

def _rough_comparison(s, t): 
    s_chars, t_chars = set(s), set(t)
    both = {'_', '-'}
    if both in s_chars or both in t_chars:
        return s == t
    if _switch_hyphens_underscores(s) == t or _switch_hyphens_underscores(t) == s:
        return True
    return s == t

def find_wheel(filename, index_urls):
    encoded_wheel = filename.replace("+", "%2B")
    package_name = filename.split("-")[0]

    found_url = None
    candidate_urls = index_urls.copy()
    while len(candidate_urls) > 0:
        url = candidate_urls.pop(-1)
        hrefs = get_hrefs(url)
        if not hrefs:
            continue
        for href in hrefs:
            href_filename = urlparse(href).path.split('/')[-1]
            if _rough_comparison(href_filename, encoded_wheel):
                _parsed = urlparse(url)
                found_url = urlunparse((_parsed.scheme, _parsed.netloc, '', '', '', '')) + href
                break
            if _rough_comparison(href, f'{package_name}/'):
                candidate_urls.append(url + '/' + href)
    
    return package_name, found_url

parser = ArgumentParser(description="Retrieve wheel URLs from PIP index urls.")
parser.add_argument('--index_urls', type=str, required=True, 
                    help='Path to file containing PIP index URLs, one per line.')
parser.add_argument('--wheels', type=str, required=True,
                    help='Path to file containing wheel filenames, one per line.')
parser.add_argument('--output', type=str, required=True,
                    help='Path to output file for resolved wheel URLs.')

args = parser.parse_args()

index_urls = proc_list(read_file(args.index_urls))
wheel_filenames = proc_list(read_file(args.wheels))
output_file = args.output

wheel_url_mapping = {}
resolved = 0

with open(output_file, 'w') as f:
    for wheel_filename in (pbar := tqdm(wheel_filenames, desc="Resolving wheels", postfix={'resolved': 0, 'total': len(wheel_filenames)})):
        package_name, found_url = find_wheel(wheel_filename, index_urls)
        
        wheel_url_mapping[(package_name)] = (wheel_filename, found_url)
        f.write(f'{package_name},{wheel_filename},{found_url if found_url is not None else "none"}\n')

        if found_url is not None:
            resolved += 1
        pbar.set_postfix({'resolved': resolved, 'total': len(wheel_filenames)})

max_package_length = max(len(package_name) for package_name in wheel_url_mapping.keys())
for package_name, (wheel_filename, url) in wheel_url_mapping.items():
    found = url is not None
    _emoji = "✅" if found else "❌"
    _msg = 'Resolved' if found else 'Not found'
    print(f"{_emoji} {package_name.ljust(max_package_length)}: {_msg}")

def download_file(url, filename):
    """Download a file from a URL."""
    try:
        r = requests.get(url, stream=True)
        r.raise_for_status()
        with open(filename, 'wb') as f:
            for chunk in tqdm(r.iter_content(chunk_size=8192), desc=f"Downloading {filename}", unit='B', unit_scale=True):
                f.write(chunk)
    except Exception as e:
        print(f"Failed to download {filename}: {e}")
