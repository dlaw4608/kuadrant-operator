#!/bin/bash

applyGateway(){

kubectl -n kuadrant-system apply -f - <<EOF
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
spec: {}
EOF

kubectl -n default apply -f ../examples/toystore/toystore.yaml

    echo "Applying Gateway"
    kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: paying-customer-gw
  namespace: istio-system
  annotations:
    kuadrant.io/namespace: kuadrant-system
    networking.istio.io/service-type: ClusterIP
spec:
  gatewayClassName: istio
  listeners:
    - name: websites
      port: 80
      protocol: HTTP
      hostname: '*.paying.website'
      allowedRoutes:
        namespaces:
          from: All

---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: free-tier-gw
  namespace: istio-system
  annotations:
    kuadrant.io/namespace: kuadrant-system
    networking.istio.io/service-type: ClusterIP
spec:
  gatewayClassName: istio
  listeners:
    - name: websites
      port: 80
      protocol: HTTP
      hostname: '*.sa.com'
      allowedRoutes:
        namespaces:
          from: All
    
---

apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: customer-domain-route
  namespace: default
spec:
  parentRefs:
  - namespace: istio-system
    name: paying-customer-gw
  hostnames:
  - 'app.paying.website'
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
  namespace: default
spec:
  parentRefs:
  - namespace: istio-system
    name: paying-customer-gw
  - namespace: istio-system
    name: free-tier-gw
  hostnames:
  - account.paying.website
  - account.joe.bloggs.sa.com
  rules:
  - backendRefs:
    - name: toystore
      port: 80

---

apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: joe-bloggs-route
  namespace: default
spec:
  parentRefs:
  - namespace: istio-system
    name: free-tier-gw
  hostnames:
  - "*.joe.bloggs.sa.com"
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
        - limit: 10
          duration: 10
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
        - limit: 3
          duration: 10
          unit: second

---

apiVersion: kuadrant.io/v1beta2
kind: RateLimitPolicy
metadata:
  name: account-rlp
  namespace: default
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: account-management-route
  limits:
    status-per-ip:
      rates:
      - limit: 6
        duration: 10
        unit: second
    

---

apiVersion: kuadrant.io/v1beta2
kind: RateLimitPolicy
metadata:
  name: paying-business-rlp
  namespace: istio-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: paying-customer-gw
  limits:
    customer-domain-route-limits:
      rates:
      - limit: 5
        duration: 10
        unit: second
    
    
---

apiVersion: kuadrant.io/v1beta2
kind: RateLimitPolicy
metadata:
  name: infra-rlp
  namespace: istio-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: free-tier-gw
  limits:
    "high-limit":
      rates:
      - limit: 5
        duration: 1
        unit: second

---

apiVersion: kuadrant.io/v1beta2
kind: RateLimitPolicy
metadata:
  name: free-tier-business-rlp
  namespace: default
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: joe-bloggs-route
  limits:
      "low-limit":
        rates:
        - limit: 2
          duration: 10
          unit: second

---

EOF
}

applyGateway