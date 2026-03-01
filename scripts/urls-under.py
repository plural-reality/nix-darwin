import sys
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
from collections import deque

def list_urls(start_url):
    # ドメインとベースパスの解析
    parsed_start = urlparse(start_url)
    base_netloc = parsed_start.netloc
    # パスが / で終わっていない場合は調整
    base_path = parsed_start.path if parsed_start.path.endswith('/') else parsed_start.path + '/'

    visited = set()
    queue = deque([start_url])

    # 探索済みに追加（初期URL）
    visited.add(start_url)

    print(f"Collecting URLs under: {start_url}", file=sys.stderr)

    while queue:
        current_url = queue.popleft()

        # 標準出力へ吐く（ここがLLMへの入力となる）
        print(current_url)

        try:
            response = requests.get(current_url, timeout=10)
            if response.status_code != 200:
                continue

            # Content-TypeがHTMLでなければスキップ
            if 'text/html' not in response.headers.get('Content-Type', ''):
                continue

            soup = BeautifulSoup(response.text, 'html.parser')

            for link in soup.find_all('a', href=True):
                href = link['href']
                full_url = urljoin(current_url, href)
                parsed_url = urlparse(full_url)

                # フラグメント(#)を除去
                full_url = full_url.split('#')[0]

                # フィルタリング条件:
                # 1. 未訪問
                # 2. 同一ドメイン
                # 3. 指定されたベースパス以下であること
                if (full_url not in visited and
                    parsed_url.netloc == base_netloc and
                    parsed_url.path.startswith(base_path)):

                    visited.add(full_url)
                    queue.append(full_url)

        except Exception as e:
            # エラーは標準エラー出力へ（パイプラインを汚さないため）
            print(f"Error fetching {current_url}: {e}", file=sys.stderr)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python crawl.py <url>", file=sys.stderr)
        sys.exit(1)

    list_urls(sys.argv[1])
