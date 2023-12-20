#!/bin/bash

# Set the working directory
work_dir="/sec/root/scripts"

# Help menu
display_help() {
    echo -e "NucleiFuzzer is a Powerful Automation tool for detecting vulnerabilities in Web Applications\n\n"
    echo -e "Usage: $0 [options]\n\n"
    echo "Options:"
    echo "  -h, --help              Display help information"
    echo "  -d, --domain            Single domain to scan for vulnerabilities"
    echo "  -l, --list              List of domains/subdomains to scan"
    echo "  -i, --input-file        File containing a list of URLs"
    echo "  -H, --header            Header value for authenticated scan (optional)"
    echo "  -o, --output-dir        Output directory (default: waymore/results)"
    echo "  -t, --threads           Number of threads for redirector.py (default: 2)"
    exit 0
}

# Function to create output directory
create_output_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
    fi
}

# Function to run subfinder and shodan, and combine their results
run_subfinder_shodan() {
    local domain="$1"
    local domain_list="$2"
    local subdomains_file="$3"

    if [ -n "$domain" ]; then
        subfinder -d "$domain" -all -o "$subdomains_file"
        shodan search --fields ip_str,port --separator , "hostname:$domain" | cut -d, -f1,2 >> "$subdomains_file"
    elif [ -n "$domain_list" ]; then
        subfinder -dL "$domain_list" -all -o "$subdomains_file"
        shodan search --fields ip_str,port --separator , -i "$domain_list" | cut -d, -f1,2 >> "$subdomains_file"
    fi
}

# Function to run httpx on subdomains and save the result
run_httpx_on_subdomains() {
    local subdomains_file="$1"
    local output_file="$2"

    cat "$subdomains_file" | httpx -o "$output_file"
}

# Function to run nuclei on alive subdomains
run_nuclei_on_subdomains() {
    local input_file="$1"
    local output_file="$2"
    nuclei -l "$input_file" -severity low,medium,high,critical -o "$output_file"
}

# Function to run katana on alive subdomains or main domain if none found
run_katana() {
    local subdomains_file="$1"
    local domain="$2"
    local output_file="$3"

    if [ -s "$subdomains_file" ]; then
        katana -list "$subdomains_file" -f qurl -silent -kf all -jc -d 10 -aff -o "$output_file"
    else
        katana -u "https://$domain" -f qurl -silent -kf all -jc -d 10 -aff -o "$output_file"
    fi
}

# Function to run waymore on the main domain or single target
run_waymore_on_domain() {
    local domain="$1"
    python3 "$work_dir/waymore/waymore.py" -i "$domain" -mode U
}

# Function to combine katana and waymore results
combine_katana_waymore_results() {
    local katana_output_file="$1"
    local waymore_output_file="$2"
    local combined_output_file="$3"
    cat "$katana_output_file" "$waymore_output_file" > "$combined_output_file"
}

# Function to sort and filter the combined result of katana and waymore
run_sort_filter() {
    local input_file="$1"
    grep "=" "$input_file" | sort -u | uniq | qsreplace FUZZ | egrep -v '(.css|.png|blog|utm_source|utm_content|utm_campaign|utm_medium|.jpeg|.jpg|.svg|.js|.gifs|.tif|.tiff|.png|.ttf|.woff|.woff2|.ico|.pdf|.svg|.txt|.gif|.wolf)'
}

# Function to run httpx on the combined result of katana and waymore
run_httpx_on_combined_results() {
    local input_file="$1"
    local output_file="$2"
    httpx -silent -mc 200,301,302,403 -l "$input_file" -o "$output_file"
}

# Function to run nuclei on live filtered endpoints
run_nuclei_on_live_endpoints() {
    local input_file="$1"
    local output_file="$2"
    nuclei -t "$work_dir/fuzzing-templates" -l "$input_file" -o "$output_file"
}

# Function to run redirector.py on live filtered endpoints
run_redirector() {
    local input_file="$1"
    local output_file="$2"
    local threads="$3"
    python3 "$work_dir/redirector.py" -l "$input_file" -p "$work_dir/payloads.txt" -o "$output_file" -t "$threads"
}

# Function to run the new tool
run_new_tool() {
    local input_file="$1"
    local output_file="$2"
    python3 "$work_dir/main.py" -f "$input_file" -o "$output_file"
}

# Function to run the complete scan
run_scan() {
    local input_type="$1"
    local domain="$2"
    local domain_list="$3"
    local urls_file="$4"
    local header="$5"
    local output_dir="$6"
    local threads="${7:-2}"  # Default to 2 threads if not provided

    # Run subfinder and shodan to find subdomains and combine their results
    subdomains_file="$output_dir/subdomains.txt"
    run_subfinder_shodan "$domain" "$domain_list" "$subdomains_file"

    # Run httpx on subdomains and save the result
    httpx_output_file="$output_dir/alive-subdomains.txt"
    run_httpx_on_subdomains "$subdomains_file" "$httpx_output_file"

    # Run nuclei on alive subdomains
    nuclei_output_file="$output_dir/nuclei_output.txt"
    run_nuclei_on_subdomains "$httpx_output_file" "$nuclei_output_file"

    # Run katana on alive subdomains or main domain
    katana_output_file="$output_dir/katana_output.txt"
    run_katana "$subdomains_file" "$domain" "$katana_output_file"

    # Run waymore on the main domain
    waymore_output_file="$output_dir/waymore.txt"
    run_waymore_on_domain "$domain"

    # Combine the results of katana and waymore
    combined_output_file="$output_dir/combined_output.txt"
    combine_katana_waymore_results "$katana_output_file" "$waymore_output_file" "$combined_output_file"

    # Sort and filter the combined result of katana and waymore
    run_sort_filter "$combined_output_file"

    # Run httpx on the combined result of katana and waymore
    httpx_combined_output_file="$output_dir/live-filter-endpoints.txt"
    run_httpx_on_combined_results "$combined_output_file" "$httpx_combined_output_file"

    # Run nuclei on live filtered endpoints
    nuclei_live_output_file="$output_dir/nuclei-live-result.txt"
    run_nuclei_on_live_endpoints "$httpx_combined_output_file" "$nuclei_live_output_file"

    # Run redirector.py on live filtered endpoints
    redirector_output_file="$output_dir/open-redirect-vuln.txt"
    run_redirector "$httpx_combined_output_file" "$redirector_output_file" "$threads"

    # Run the new tool on the output of httpx
    run_new_tool "$httpx_combined_output_file" "$output_dir/domain-xss-vulnerable.txt"

    echo "NucleiFuzzer completed successfully. Results saved in $output_dir/"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            display_help
            ;;
        -d|--domain)
            input_type="domain"
            domain="$2"
            shift
            shift
            ;;
        -l|--list)
            input_type="list"
            domain_list="$2"
            shift
            shift
            ;;
        -i|--input-file)
            input_type="urls"
            urls_file="$2"
            shift
            shift
            ;;
        -H|--header)
            header="$2"
            shift
            shift
            ;;
        -o|--output-dir)
            output_dir="$2"
            shift
            shift
            ;;
        -t|--threads)
            threads="$2"
            shift
            shift
            ;;
        *)
            echo "Unknown option: $key"
            display_help
            ;;
    esac
done

# If no input type is specified, display help
if [ -z "$input_type" ]; then
    display_help
fi

# If no output directory is specified, use the default
output_dir="${output_dir:-$work_dir/waymore/results}"

# Run the scan
run_scan "$input_type" "$domain" "$domain_list" "$urls_file" "$header" "$output_dir" "$threads"
