#!/bin/bash

applyGateway(){
    echo "Applying Gateway"
    kubectl -n istio-system apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: paying-customer-gw
  annotations:
    kuadrant.io/namespace: kuadrant-system
    networking.istio.io/service-type: ClusterIP
spec:
  gatewayClassName: istio
  listeners:
    - name: websites
      port: 80
      protocol: HTTP
      hostname: '*.website'
      allowedRoutes:
        namespaces:
          from: All
    - name: apis
      port: 80
      protocol: HTTP
      hostname: '*.io'
      allowedRoutes:
        namespaces:
          from: All
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: free-tier-gw
spec:
  gatewayClassName: istio
  listeners:
    - name: websites
      port: 80
      protocol: HTTP
      hostname: '*.website'
      allowedRoutes:
        namespaces:
          from: All
    - name: apis
      port: 80
      protocol: HTTP
      hostname: '*.io'
      allowedRoutes:
        namespaces:
          from: All
---

apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: customer-domain-route
spec:
  parentRefs:
  - namespace: istio-system
    name: paying-customer-gw
  hostnames:
  - '*.website'
  rules:
  - matches:
    - method: GET
      path: 
        type: PathPrefix
        value: "/v1/"
    - method: POST
      path: 
        type: PathPrefix
        value: "/v1/"
    backendRefs:
    - name: toystore
      port: 80
  - matches:
    - path: 
        type: PathPrefix
        value: "/assets/"
    backendRefs:
    - name: toystore
      port: 80

---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: account-management-route
spec:
  parentRefs:
  - namespace: istio-system
    name: paying-customer-gw
  - namespace: istio-system
    name: free-tier-gw
  hostnames:
  - status.io
  - status.local
  rules:
  - backendRefs:
    - name: toystore
      port: 80

---

apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: joe-bloggs-route
spec:
  parentRefs:
  - namespace: istio-system
    name: free-tier-gw
  rules:
  - matches:
    - path: 
        type: PathPrefix
        value: "/v1/"
    - path: 
        type: PathPrefix
        value: "/v2/"
    backendRefs:
    - name: toystore
      port: 80

---

apiVersion: kuadrant.io/v1beta2
kind: RateLimitPolicy
metadata:
  name: paying-customer-rate-limit
  namespace: istio-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: paying-customer-gw
  limits:
    "high-priority":
      rates:
        - limit: 100
          duration: 1
          unit: second

---

apiVersion: kuadrant.io/v1beta2
kind: RateLimitPolicy
metadata:
  name: free-tier-rate-limit
  namespace: istio-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: free-tier-gw
  limits:
    "low-priority":
      rates:
        - limit: 10
          duration: 1
          unit: second

EOF
}

applyGateway