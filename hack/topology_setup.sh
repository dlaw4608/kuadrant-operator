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

EOF
}

applyGateway