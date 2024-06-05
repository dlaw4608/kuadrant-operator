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
      name: student-gw
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
            hostname: '*.student.website'
            allowedRoutes:
                namespaces:
                from: All
    ---

    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: Gateway
    metadata:
      name: teacher-gw
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
            hostname: '*.teacher.website'
            allowedRoutes:
                namespaces:
                from: All
    ---

    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: Gateway
    metadata:
      name: admin-gw
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
            hostname: '*.admin.website'
            allowedRoutes:
                namespaces:
                from: All
    ---


    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: HTTPRoute
    metadata:
      name: student-domain-route
      namespace: default
    spec:
      parentRefs:
        - name: student-gw
          namespace: istio-system
      hostnames:
      - '*.student.website'
      rules:
        - matches:
            - uri:
                prefix: /student
          filters:
            - name: kuadrant
              args:
                namespace: kuadrant-system
                service: student
                version: v1
                port: 80

    ---

    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: HTTPRoute
    metadata:
      name: teacher-domain-route
      namespace: default
    spec:
      parentRefs:
        - name: teacher-gw
          namespace: istio-system
      hostnames:
      - '*.teacher.website'
      rules:
        - matches:
            - uri:
                prefix: /teacher
          filters:
            - name: kuadrant
              args:
                namespace: kuadrant-system
                service: teacher
                version: v1
                port: 80

    ---

    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: HTTPRoute
    metadata:
      name: admin-domain-route
      namespace: default
    spec:
      parentRefs:
        - name: admin-gw
          namespace: istio-system
      hostnames:
      - '*.admin.website'
      rules:
        - matches:
            - uri:
                prefix: /admin
          filters:
            - name: kuadrant
              args:
                namespace: kuadrant-system
                service: admin
                version: v1
                port: 80

    ---

    apiVersion: kuadrant.io/v1beta2
    kind: RateLimitPolicy
    metadata:
      name: student-rate-limit
      namespace: istio-system
    spec:
      targetRef:
        group: gateway.networking.k8s.io
        kind: Gateway
        name: student-gw
        limits
          "low-priority":
            rates:
              - limit: 3
                duration 10
                unit: second

    ---

    apiVersion: kuadrant.io/v1beta2
    kind: RatelimitPolicy
    metadata:
      name: teacher-rate-limit
      namespace: default
    spec: 
      targetRef:
        group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: teacher-domain-route
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
      name: admin-rate-limit
      namespace: default
    spec:
      targetRef:
        group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: admin-domain-route
      limits:
        status-per-ip:
          rates:
            - limit: 6
              duration: 10
              unit: second

    ---

    apiVersion: kuadrant.io/v1beta2
    kind: AuthPolicy
    metadata:
      name: student-auth-policy
      namespace: default
    spec:
      targetRef:
        group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: student-domain-route
      rules:
        - jwt:
            issuer: "https://auth.student.website"
            jwksUri: "https://auth.student.website/.well-known/jwks.json"
            audiences:
              - "student-website"
            forwardPayload: true    

    ---

    apiVersion: kuadrant.io/v1beta2
    kind: AuthPolicy
    metadata:
      name: teacher-auth-policy
      namespace: default
    spec:
      targetRef:
        group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: teacher-domain-route
      rules:
        - jwt:
            issuer: "https://auth.teacher.website"
            jwksUri: "https://auth.teacher.website/.well-known/jwks.json"
            audiences:
              - "teacher-website"
            forwardPayload: true
    
    ---

    apiVersion: kuadrant.io/v1beta2
    kind: AuthPolicy
    metadata:
      name: admin-auth-policy
      namespace: default
    spec:
      targetRef:
        group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: admin-domain-route
      rules:
        - jwt:
            issuer: "https://auth.admin.website"
            jwksUri: "https://auth.admin.website/.well-known/jwks.json"
            audiences:
              - "admin-website"
            forwardPayload: true
    
EOF
    


}

applyGateway