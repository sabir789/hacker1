import requests
from urllib.parse import urlparse, urljoin
from colorama import Fore
import threading
from optparse import OptionParser

parser = OptionParser()
parser.add_option('-l', dest='url_list', help="Enter the file containing URLs")
parser.add_option('-p', dest='payloads', help="Enter payload file")
parser.add_option('-t', dest='thread', help="Enter thread value (1: Fastest 100: Normal)")
parser.add_option('-c', dest='cookies', help='Enter cookies value (For authenticated endpoints)')
parser.add_option('-o', dest='output_file', help='Enter output file name')

val, arguments = parser.parse_args()

print(Fore.BLUE + """
              
             Open Redirection Scanner
                 Made By 0xSabir
""")

class Scanner:
    def __init__(self, url_list, payloads, output_file, thread, cookies=None):
        process = []
        self.url_list = url_list
        self.payloads = payloads
        self.output_file = output_file
        self.cookies = cookies

        urls = self.open_file(self.url_list)
        final_payloads = self.payload_parser(payloads)

        if thread:
            final_urls = self.divide_list(urls, int(thread))
        else:
            final_urls = self.divide_list(urls, 100)

        index = 0
        for chunk in final_urls:
            process.append(threading.Thread(target=self.scanner, args=(chunk, final_payloads)))
            process[index].start()
            index += 1

        for i in process:
            i.join()

    def open_file(self, file_path):
        urls = []
        with open(file_path, 'r') as file:
            full_data = file.read().split()
            for i in full_data:
                urls.append(i)
        return urls

    def payload_parser(self, payload_file):
        final_payloads = []
        total_payload = self.open_file(payload_file)
        for payload in total_payload:
            if 'whitelist' in payload:
                final_payload = payload.replace('%whitelist%', val.whitelist_domain)
                final_payloads.append(final_payload)
                continue
            final_payloads.append(payload)
        print(Fore.GREEN + f'[+]{len(final_payloads)} PAYLOADS LOADED')
        return final_payloads

    def divide_list(self, lst, n):
        final_lst = [lst[i:i + n] for i in range(0, len(lst), n)]
        return final_lst

    def parse_url(self, url, payload):
        return urljoin(url, f'?{urlparse(url).query.split("=")[0]}={payload}')

    def scanner(self, urls, payloads):
        for url in urls:
            for payload in payloads:
                final_url = self.parse_url(url, payload)
                try:
                    if not self.cookies:
                        response = requests.get(final_url, allow_redirects=False)
                    else:
                        response = requests.get(final_url, allow_redirects=False, cookies=self.cookies)
                except UnicodeDecodeError:
                    continue

                try:
                    net_loc = urlparse(response.headers['Location']).netloc
                except KeyError:
                    continue

                if 'example.com' in net_loc:
                    print(Fore.RED + f'Vulnerable {final_url}')
                    with open(self.output_file, 'a') as out_file:
                        out_file.write(f'{final_url}\n')

                if not net_loc:
                    continue

                if response.status_code in range(400, 500):
                    print(Fore.RED + f"Warning: GETTING {response.status_code}")
                    continue

if __name__ == "__main__":
    Scanner(val.url_list, val.payloads, val.output_file, val.thread, val.cookies)
