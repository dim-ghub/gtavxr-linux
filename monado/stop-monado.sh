#!/usr/bin/env bash
pkill -x monado-service && echo "monado-service stopped." || echo "monado-service wasn't running."
pkill -f 'sleep infinity$' 2>/dev/null; true
