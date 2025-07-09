#!/usr/bin/env bash

# DNS Configuration Audit Script
# For macOS - Comprehensive DNS diagnostics for newly configured domains
# Usage: ./dns_audit.sh yourdomain.com

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if domain is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <domain.com>"
  exit 1
fi

DOMAIN=$1
AUDIT_LOG="dns_audit_${DOMAIN}_$(date +%Y%m%d_%H%M%S).log"

# Function to print colored output
print_header() {
  echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$AUDIT_LOG"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}" | tee -a "$AUDIT_LOG"
}

print_error() {
  echo -e "${RED}✗ $1${NC}" | tee -a "$AUDIT_LOG"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$AUDIT_LOG"
}

print_info() {
  echo -e "$1" | tee -a "$AUDIT_LOG"
}

# Start audit
echo -e "${BLUE}DNS Configuration Audit for: $DOMAIN${NC}" | tee "$AUDIT_LOG"
echo -e "Audit started at: $(date)" | tee -a "$AUDIT_LOG"
echo -e "Results saved to: $AUDIT_LOG\n" | tee -a "$AUDIT_LOG"

# 1. PRE-FLIGHT CHECKS
print_header "1. PRE-FLIGHT CHECKS"

# Check required tools
print_info "Checking required tools..."
MISSING_TOOLS=0
for tool in dig nslookup host whois nc curl openssl; do
  if command -v $tool >/dev/null 2>&1; then
    print_success "$tool is available"
  else
    print_error "$tool is NOT available"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
  fi
done

if [ $MISSING_TOOLS -gt 0 ]; then
  print_warning "Install missing tools with: brew install bind whois netcat curl openssl"
fi

# Clear DNS cache
print_info "\nClearing DNS cache..."
sudo dscacheutil -flushcache 2>/dev/null && sudo killall -HUP mDNSResponder 2>/dev/null
print_success "DNS cache cleared"

# Get domain info
print_info "\nGathering domain information..."
AUTH_NS=$(dig +short NS $DOMAIN | head -1)
if [ -z "$AUTH_NS" ]; then
  print_error "No nameservers found for $DOMAIN"
  exit 1
else
  print_success "Authoritative nameserver: $AUTH_NS"
fi

# Get all nameservers
print_info "\nAll nameservers:"
dig +short NS $DOMAIN | while read ns; do
  print_info "  - $ns"
done

# Get registrar info
print_info "\nRegistrar information:"
whois $DOMAIN 2>/dev/null | grep -E "(Registrar:|Name Server:|DNSSEC:|Status:)" | while read line; do
  print_info "  $line"
done

# 2. DNS PROPAGATION VERIFICATION
print_header "2. DNS PROPAGATION VERIFICATION"

# Check multiple public resolvers
print_info "Testing major public DNS servers..."
PROPAGATION_ISSUES=0
FIRST_IP=""
for resolver in 8.8.8.8 1.1.1.1 208.67.222.222 9.9.9.9; do
  IP=$(dig @$resolver $DOMAIN +short 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -1)
  if [ -z "$IP" ]; then
    print_error "$resolver - No response"
    PROPAGATION_ISSUES=$((PROPAGATION_ISSUES + 1))
  else
    if [ -z "$FIRST_IP" ]; then
      FIRST_IP=$IP
    fi
    if [ "$IP" = "$FIRST_IP" ]; then
      print_success "$resolver - $IP"
    else
      print_error "$resolver - $IP (INCONSISTENT!)"
      PROPAGATION_ISSUES=$((PROPAGATION_ISSUES + 1))
    fi
  fi
done

if [ $PROPAGATION_ISSUES -eq 0 ]; then
  print_success "DNS propagation is consistent across all tested resolvers"
else
  print_warning "DNS propagation issues detected - records may still be propagating"
fi

# Check authoritative nameservers
print_info "\nChecking authoritative nameservers directly..."
dig +short NS $DOMAIN | while read ns; do
  print_info "\nQuerying $ns:"
  dig @$ns $DOMAIN +noall +answer 2>/dev/null | while read line; do
    print_info "  $line"
  done
done

# Trace DNS resolution path
print_info "\nDNS resolution trace:"
dig +trace $DOMAIN 2>/dev/null | tail -10 | while read line; do
  print_info "  $line"
done

# 3. RECORD-BY-RECORD VALIDATION
print_header "3. RECORD-BY-RECORD VALIDATION"

# A Record validation
print_info "\nA Record Check:"
A_RECORD=$(dig $DOMAIN A +short)
if [ -z "$A_RECORD" ]; then
  print_error "No A record found"
else
  print_success "A record: $A_RECORD"

  # Test connectivity
  if ping -c 1 -W 2 $A_RECORD >/dev/null 2>&1; then
    print_success "IP is reachable via ICMP"
  else
    print_warning "IP not reachable via ICMP (may be blocked by firewall)"
  fi

  # Reverse DNS
  REVERSE_DNS=$(dig +short -x $A_RECORD)
  if [ -n "$REVERSE_DNS" ]; then
    print_success "Reverse DNS: $REVERSE_DNS"
  else
    print_warning "No reverse DNS configured"
  fi
fi

# MX Record validation
print_info "\nMX Record Check:"
MX_COUNT=0
dig $DOMAIN MX +short | sort -n | while read priority mx; do
  MX_COUNT=$((MX_COUNT + 1))
  print_info "  Priority $priority: $mx"

  # Resolve MX host
  MX_IP=$(dig +short $mx A)
  if [ -n "$MX_IP" ]; then
    print_success "    Resolves to: $MX_IP"

    # Test SMTP connectivity
    if nc -zv -w2 $mx 25 >/dev/null 2>&1; then
      print_success "    SMTP port 25 is open"
    else
      print_error "    SMTP port 25 is NOT reachable"
    fi
  else
    print_error "    Does NOT resolve to an IP"
  fi
done

if [ $MX_COUNT -eq 0 ]; then
  print_error "No MX records found"
fi

# TXT Record validation
print_info "\nTXT Record Check:"
TXT_RECORDS=$(dig $DOMAIN TXT +short)
if [ -z "$TXT_RECORDS" ]; then
  print_warning "No TXT records found"
else
  # SPF Check
  SPF=$(echo "$TXT_RECORDS" | grep "v=spf1")
  if [ -n "$SPF" ]; then
    print_success "SPF record found: $SPF"
    if echo "$SPF" | grep -q "\-all"; then
      print_success "  SPF uses hard fail (-all)"
    elif echo "$SPF" | grep -q "~all"; then
      print_warning "  SPF uses soft fail (~all)"
    elif echo "$SPF" | grep -q "\?all"; then
      print_warning "  SPF uses neutral (?all)"
    elif echo "$SPF" | grep -q "\+all"; then
      print_error "  SPF allows all (+all) - NOT SECURE!"
    fi
  else
    print_error "No SPF record found"
  fi

  # Domain verification records
  if echo "$TXT_RECORDS" | grep -qE "(google-site-verification|MS=|amazonses|_domainkey)"; then
    print_success "Domain verification records found"
  fi
fi

# DMARC Check
print_info "\nDMARC Record Check:"
DMARC=$(dig _dmarc.$DOMAIN TXT +short)
if [ -n "$DMARC" ]; then
  print_success "DMARC record found: $DMARC"
  if echo "$DMARC" | grep -q "p=reject"; then
    print_success "  DMARC policy: reject (strongest)"
  elif echo "$DMARC" | grep -q "p=quarantine"; then
    print_warning "  DMARC policy: quarantine (moderate)"
  elif echo "$DMARC" | grep -q "p=none"; then
    print_warning "  DMARC policy: none (monitoring only)"
  fi
else
  print_error "No DMARC record found"
fi

# DKIM Check
print_info "\nDKIM Selector Check:"
DKIM_FOUND=0
for selector in default google dkim mail key1 selector1 selector2 k1 k2; do
  DKIM_RECORD=$(dig +short ${selector}._domainkey.$DOMAIN TXT 2>/dev/null)
  if [ -n "$DKIM_RECORD" ]; then
    print_success "DKIM selector '$selector' found"
    DKIM_FOUND=1
  fi
done
if [ $DKIM_FOUND -eq 0 ]; then
  print_warning "No common DKIM selectors found (may use custom selector)"
fi

# CNAME Record validation
print_info "\nCNAME Record Check (www subdomain):"
WWW_RECORD=$(dig www.$DOMAIN CNAME +short)
if [ -n "$WWW_RECORD" ]; then
  print_success "www CNAME: $WWW_RECORD"
else
  # Check if www has A record instead
  WWW_A=$(dig www.$DOMAIN A +short)
  if [ -n "$WWW_A" ]; then
    print_info "www has A record: $WWW_A (not CNAME)"
  else
    print_warning "www subdomain not configured"
  fi
fi

# 4. SECURITY CONFIGURATION AUDIT
print_header "4. SECURITY CONFIGURATION AUDIT"

# DNSSEC Check
print_info "\nDNSSEC Status:"
DNSSEC_KEYS=$(dig $DOMAIN DNSKEY +short)
if [ -n "$DNSSEC_KEYS" ]; then
  print_success "DNSSEC is enabled"

  # Verify DNSSEC validation
  if dig @8.8.8.8 $DOMAIN +dnssec +short | grep -q "ad"; then
    print_success "DNSSEC validation successful"
  else
    print_warning "DNSSEC enabled but validation issues detected"
  fi
else
  print_warning "DNSSEC is NOT enabled"
fi

# CAA Record Check
print_info "\nCAA Record Check:"
CAA_RECORD=$(dig $DOMAIN CAA +short)
if [ -n "$CAA_RECORD" ]; then
  print_success "CAA records found:"
  echo "$CAA_RECORD" | while read line; do
    print_info "  $line"
  done
else
  print_warning "No CAA records found (allows any CA to issue certificates)"
fi

# Check for zone transfer vulnerability
print_info "\nZone Transfer Security Check:"
if dig @$AUTH_NS $DOMAIN AXFR | grep -q "Transfer failed"; then
  print_success "Zone transfer properly denied"
else
  print_error "Zone transfer may be allowed - SECURITY RISK!"
fi

# 5. PERFORMANCE AND CONNECTIVITY TESTS
print_header "5. PERFORMANCE AND CONNECTIVITY TESTS"

# DNS Query Performance
print_info "\nDNS Query Performance:"
TOTAL_TIME=0
COUNT=0
for i in {1..5}; do
  QUERY_TIME=$(dig $DOMAIN | grep "Query time:" | awk '{print $4}')
  if [ -n "$QUERY_TIME" ]; then
    TOTAL_TIME=$((TOTAL_TIME + QUERY_TIME))
    COUNT=$((COUNT + 1))
  fi
done
if [ $COUNT -gt 0 ]; then
  AVG_TIME=$((TOTAL_TIME / COUNT))
  if [ $AVG_TIME -lt 50 ]; then
    print_success "Average query time: ${AVG_TIME}ms (excellent)"
  elif [ $AVG_TIME -lt 200 ]; then
    print_warning "Average query time: ${AVG_TIME}ms (acceptable)"
  else
    print_error "Average query time: ${AVG_TIME}ms (slow)"
  fi
fi

# HTTP/HTTPS Connectivity
print_info "\nHTTP/HTTPS Connectivity:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 http://$DOMAIN 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
  print_success "HTTP responds with: $HTTP_CODE"
else
  print_warning "HTTP response code: $HTTP_CODE"
fi

# SSL Certificate Check
print_info "\nSSL Certificate Check:"
if echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
  CERT_INFO=$(echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -dates -subject 2>/dev/null)
  print_success "SSL certificate is valid"
  echo "$CERT_INFO" | while read line; do
    print_info "  $line"
  done
else
  print_warning "Could not verify SSL certificate"
fi

# 6. SUMMARY AND RECOMMENDATIONS
print_header "6. SUMMARY AND RECOMMENDATIONS"

print_info "\nQuick Health Check Summary:"

# Define checks
declare -a checks=(
  "Nameservers responding:dig +short @$AUTH_NS $DOMAIN A"
  "A record exists:dig +short $DOMAIN A"
  "MX records configured:dig +short $DOMAIN MX"
  "SPF record present:dig +short $DOMAIN TXT | grep -q 'v=spf1'"
  "DMARC configured:dig +short _dmarc.$DOMAIN TXT | grep -q 'v=DMARC1'"
  "WWW accessible:dig +short www.$DOMAIN"
  "DNSSEC enabled:dig +short $DOMAIN DNSKEY"
  "SSL certificate valid:echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | grep -q 'Verify return code: 0'"
)

ISSUES_FOUND=0
for check in "${checks[@]}"; do
  IFS=':' read -r desc cmd <<<"$check"
  if eval "$cmd" >/dev/null 2>&1; then
    print_success "$desc"
  else
    print_error "$desc"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
done

print_info "\n${BLUE}Audit Summary:${NC}"
if [ $ISSUES_FOUND -eq 0 ]; then
  print_success "All basic checks passed! Your DNS configuration looks good."
else
  print_warning "Found $ISSUES_FOUND potential issues that need attention."
fi

print_info "\n${BLUE}Recommendations:${NC}"
print_info "1. Monitor DNS propagation for 24-48 hours"
print_info "2. Consider enabling DNSSEC if not already enabled"
print_info "3. Implement DMARC with progressive policy (none → quarantine → reject)"
print_info "4. Add CAA records to control certificate issuance"
print_info "5. Configure reverse DNS for mail servers"
print_info "6. Regularly review and update DNS records"

print_info "\n${BLUE}Useful Online Tools:${NC}"
print_info "- MXToolbox (mxtoolbox.com) - Email and DNS diagnostics"
print_info "- DNSChecker (dnschecker.org) - Global propagation monitoring"
print_info "- SSL Labs (ssllabs.com/ssltest) - HTTPS configuration analysis"
print_info "- DNSViz (dnsviz.net) - Visual DNSSEC validation"

print_info "\n${GREEN}Audit completed at: $(date)${NC}"
print_info "Full results saved to: $AUDIT_LOG"
