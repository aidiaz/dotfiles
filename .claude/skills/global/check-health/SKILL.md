---
name: check-health
description: Check the health status of the 3 StrongByForm production endpoints (data, vera, erp). Use when the user runs /check-health or asks to check endpoint health.
---

# Health Check

Check the health of the 3 StrongByForm production endpoints and report their status, HTTP code, and response time.

## Endpoints

- `https://data.strongbyform.com/api/health`
- `https://vera.strongbyform.com/health`
- `https://erp.strongbyform.com/api/method/ping`

## Instructions

Run the following bash commands **in parallel** (one per endpoint) to check all three simultaneously:

```bash
curl -s -o /tmp/health_data.txt -w "%{http_code} %{time_total}" -m 10 "https://data.strongbyform.com/api/health" 2>&1; echo ""; cat /tmp/health_data.txt
```

```bash
curl -s -o /tmp/health_vera.txt -w "%{http_code} %{time_total}" -m 10 "https://vera.strongbyform.com/health" 2>&1; echo ""; cat /tmp/health_vera.txt
```

```bash
curl -s -o /tmp/health_erp.txt -w "%{http_code} %{time_total}" -m 10 "https://erp.strongbyform.com/api/method/ping" 2>&1; echo ""; cat /tmp/health_erp.txt
```

For each endpoint, use this single command pattern to get both status and body:

```bash
result=$(curl -s -w "\n---STATUS:%{http_code}---TIME:%{time_total}s" -m 10 "<URL>"); \
body=$(echo "$result" | sed '/---STATUS:/d'); \
meta=$(echo "$result" | grep "---STATUS:"); \
http_code=$(echo "$meta" | sed 's/.*---STATUS:\([0-9]*\).*/\1/'); \
time=$(echo "$meta" | sed 's/.*---TIME:\(.*\)/\1/'); \
echo "HTTP: $http_code | Time: ${time} | Body: $body"
```

## Output Format

Present results as a clean table or list:

```
Health Check Results — <timestamp>

  data  | https://data.strongbyform.com/api/health
  ✅ UP   HTTP 200 | 123ms | {"status":"ok"}

  vera  | https://vera.strongbyform.com/health  
  ✅ UP   HTTP 200 | 98ms  | {"status":"ok"}

  erp   | https://erp.strongbyform.com/api/method/ping
  ❌ DOWN HTTP 503 | 45ms  | {"message":"error"}
```

Status rules:
- 2xx → UP
- anything else → DOWN (show actual HTTP code)
- timeout or no response → UNREACHABLE

Always run all 3 checks in parallel for speed.
