# Lab 05: GCP HA VPN & Dynamic BGP Routing (Console Deployment)

Este laboratorio demuestra la interconexión de dos Redes de VPC distintas dentro de Google Cloud Platform (GCP) mediante un enlace **HA VPN de Alta Disponibilidad** con **enrutamiento dinámico BGP** y **balanceo por ECMP (Equal-Cost Multi-Path)**.

A diferencia de despliegues automatizados con IaC, esta arquitectura se configuró manualmente desde la **Consola de GCP** con el objetivo de validar patrones de diseño de red, profundizar en el diagnóstico de sesiones BGP en tiempo real y demostrar fluidez en la administración visual de la infraestructura.

flowchart LR
    %% Estilos de Nodos y Subgrafos
    classDef vpcProd fill:#e8f0fe,stroke:#1a73e8,stroke-width:2px,color:#174ea6;
    classDef vpcOnPrem fill:#fce8e6,stroke:#ea4335,stroke-width:2px,color:#a50e0e;
    classDef router fill:#feefc3,stroke:#fbbc04,stroke-width:2px,color:#b06000;
    classDef vm fill:#e6f4ea,stroke:#34a853,stroke-width:2px,color:#137333;
    classDef gateway fill:#f1f3f4,stroke:#5f6368,stroke-width:2px,color:#202124;

    %% VPC GCP PRODUCCION
    subgraph VPC1 ["VPC: vpc-gcp-production"]
        direction TB
        
        subgraph REGION1 ["us-central1 (Iowa)"]
            VM1["VM: vm-gcp-us-central1-01<br/>IP: 10.1.10.2"]:::vm
            CR1["Cloud Router: cr-gcp-us-central1<br/>ASN: 65001"]:::router
        end

        subgraph GW1 ["HA VPN Gateway: vpngw-gcp-us-central1"]
            GW1_IF0["Interfaz 0<br/>35.242.112.249"]:::gateway
            GW1_IF1["Interfaz 1<br/>34.157.235.253"]:::gateway
        end

        VM1 --- CR1
        CR1 --- GW1_IF0
        CR1 --- GW1_IF1
    end

    %% VPC ON-PREM SIMULADA
    subgraph VPC2 ["VPC: vpc-onprem-simulated"]
        direction TB

        subgraph GW2 ["HA VPN Gateway: vpngw-on-prem-us-central1"]
            GW2_IF0["Interfaz 0<br/>34.128.33.228"]:::gateway
            GW2_IF1["Interfaz 1<br/>34.184.42.180"]:::gateway
        end

        subgraph REGION2 ["us-central1 (Iowa)"]
            CR2["Cloud Router: cr-onprem-us-central1<br/>ASN: 65002"]:::router
            VM2["VM: vm-onprem-us-central1-01<br/>IP: 10.2.10.2"]:::vm
        end

        GW2_IF0 --- CR2
        GW2_IF1 --- CR2
        CR2 --- VM2
    end

    %% TUNELES IPSEC Y BGP
    GW1_IF0 <== "<b>Tunnel 0 (if0)</b><br/>BGP: 169.254.116.77/30 <--> .78<br/>MED: 100" ==> GW2_IF0
    GW1_IF1 <== "<b>Tunnel 1 (if1)</b><br/>BGP: 169.254.139.10/30 <--> .9<br/>MED: 100" ==> GW2_IF1

    %% Aplicar clases
    class VPC1 vpcProd;
    class VPC2 vpcOnPrem;

---

## 📐 Arquitectura del Sistema

La topología simula la interconexión entre una red corporativa de producción (`vpc-gcp-production`) y un centro de datos On-Premises simulado (`vpc-onprem-simulated`).

* **VPC GCP (Producción):**
  * **Regiones:** `us-central1` (Iowa) y `us-west1` (Oregon)
  * **Cloud Router:** `cr-gcp-us-central1` (ASN: `65001`)
  * **Gateway HA VPN:** `vpngw-gcp-us-central1` (Dual-homed: Interfaz 0 e Interfaz 1)
  * **VM de Prueba:** `vm-gcp-us-central1-01` (`10.1.10.2`)

* **VPC On-Prem (Simulada):**
  * **Regiones:** `us-central1` (Iowa) y `us-west1` (Oregon)
  * **Cloud Router:** `cr-onprem-us-central1` (ASN: `65002`)
  * **Gateway HA VPN:** `vpngw-onprem-us-central1` (Dual-homed: Interfaz 0 e Interfaz 1)
  * **VM de Prueba:** `vm-onprem-us-central1-01` (`10.2.10.2`)

* **Enrutamiento y Redundancia:**
  * **Esquema BGP:** Activo/Activo (ECMP)
  * **Prioridad BGP (MED):** `100` asignado en los 4 túneles.

---

## 🖥️ Instancias de Prueba (Compute Engine)

Para validar la conectividad privada de extremo a extremo, se desplegaron máquinas virtuales tipo `e2-micro` dentro de las subredes de cada VPC:

![Instancias de VM](images/gcp-vms-instances-list.png)

* **`vm-gcp-us-central1-01`**: IP Privada `10.1.10.2` (VPC GCP Prod)
* **`vm-onprem-us-central1-01`**: IP Privada `10.2.10.2` (VPC On-Prem Simulada)

---

## 🛠️ Troubleshooting Clave: Alineación Manual de Subredes BGP `/30`

Durante la creación del túnel HA VPN en la Consola, se seleccionó inicialmente la **asignación automática** para las direcciones IP Link-Local BGP (`169.254.x.x`).

### El Problema:
GCP generó subredes `/30` independientes en cada extremo, haciendo que los Cloud Routers intentaran establecer la sesión BGP contra direcciones IP incompatibles:

* **Túnel 0 (`if0`):** GCP enviaba paquetes a `.116.78`, mientras On-Prem escuchaba en `.254.217`.
* **Túnel 1 (`if1`):** GCP enviaba paquetes a `.170.2`, mientras On-Prem escuchaba en `.139.9`.

Esto provocó que las sesiones BGP permanecieran en estado **Inactivo (Inactive)**.

### La Solución:
Dado que la consola no permite editar directamente las IPs BGP asignadas automáticamente en una sesión ya creada, se reasignaron manualmente los pares BGP Link-Local en subredes `/30` cruzadas:

* **Túnel 0 (`if0`):**
  * Router GCP: `169.254.116.77/30` | Peer: `169.254.116.78`
  * Router On-Prem: `169.254.116.78/30` | Peer: `169.254.116.77`
* **Túnel 1 (`if1`):**
  * Router GCP: `169.254.139.10/30` | Peer: `169.254.139.9`
  * Router On-Prem: `169.254.139.9/30` | Peer: `169.254.139.10`

---

## ✅ Resultados y Evidencia

### 1. Estado de las Sesiones BGP (Established/Active)
Una vez alineadas las direcciones Link-Local `/30`, las 4 sesiones BGP pasaron a estado **Activo (Verde)** de forma inmediata:

![Estado de Sesiones BGP](images/bgp-sessions-established.png)

### 2. Validación de Conectividad (Ping ICMP Bidireccional)
Se comprobó el intercambio de tráfico ICMP entre las instancias de ambas VPCs a través de los túneles IPsec encriptados:

![Prueba de Ping Bidireccional](images/icmp-ping-validation.png)

* **Prueba GCP Prod → On-Prem:**
  `ping 10.2.10.2` ejecutado desde `vm-gcp-us-central1-01` con **0% packet loss** y latencia media de ~1.9 ms.
* **Prueba On-Prem → GCP Prod:**
  `ping 10.1.10.2` ejecutado desde `vm-onprem-us-central1-01` con **0% packet loss** y latencia media de ~2.1 ms.

---

## 🔍 Comandos de Verificación (Google Cloud CLI)

Para validar el estado de los túneles y las sesiones BGP mediante la CLI de Cloud Shell:

```bash
# Listar y verificar el estado operativo de los túneles VPN
fertriana21@cloudshell:~ (cl-demo-learn-507500)$ gcloud compute vpn-tunnels list
NAME: vpn-tnl-gcp-to-onprem-if0
REGION: us-central1
GATEWAY: vpngw-gcp-us-central1
PEER_ADDRESS: 34.128.33.228

NAME: vpn-tnl-gcp-to-onprem-if1
REGION: us-central1
GATEWAY: vpngw-gcp-us-central1
PEER_ADDRESS: 34.184.42.180

NAME: vpn-tnl-onprem-to-gcp-if0
REGION: us-central1
GATEWAY: vpngw-on-prem-us-central1
PEER_ADDRESS: 35.242.112.249

NAME: vpn-tnl-onprem-to-gcp-if1
REGION: us-central1
GATEWAY: vpngw-on-prem-us-central1
PEER_ADDRESS: 34.157.235.253


# Inspeccionar las rutas aprendidas por BGP en el Cloud Router de GCP
fertriana21@cloudshell:~ (cl-demo-learn-507500)$ gcloud compute routers describe cr-gcp-us-central1 \
    --region=us-central1 \
    --format="yaml(bgpPeers, status)"
bgpPeers:
- advertiseMode: DEFAULT
  advertisedRoutePriority: 100
  bfd:
    minReceiveInterval: 1000
    minTransmitInterval: 1000
    multiplier: 5
    sessionInitializationMode: DISABLED
  enable: 'TRUE'
  enableIpv4: true
  enableIpv6: false
  interfaceName: if-bgp-sess-gcp-to-onprem-if0
  ipAddress: 169.254.116.77
  name: bgp-sess-gcp-to-onprem-if0
  peerAsn: 65002
  peerIpAddress: 169.254.116.78
- advertiseMode: DEFAULT
  advertisedRoutePriority: 100
  bfd:
    minReceiveInterval: 1000
    minTransmitInterval: 1000
    multiplier: 5
    sessionInitializationMode: DISABLED
  enable: 'TRUE'
  enableIpv4: true
  enableIpv6: false
  interfaceName: if-bgp-sess-gcp-to-onprem-if1
  ipAddress: 169.254.139.10
  name: bgp-sess-gcp-to-onprem-if1
  peerAsn: 65002
  peerIpAddress: 169.254.139.9
