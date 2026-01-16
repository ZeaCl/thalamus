#!/usr/bin/env python3
"""
Script para listar droplets y dominios de Digital Ocean
Lee el token desde .env para seguridad
"""

import requests
import os
from pathlib import Path

def load_env():
    """Carga variables de entorno desde .env"""
    env_path = Path(__file__).parent.parent / '.env'

    if not env_path.exists():
        print(f"❌ Error: No se encontró {env_path}")
        print("   Crea el archivo .env desde .env.example")
        exit(1)

    env_vars = {}
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip()

    return env_vars

def list_droplets(token):
    """Lista todos los droplets disponibles"""
    url = "https://api.digitalocean.com/v2/droplets"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    response = requests.get(url, headers=headers)

    if response.status_code != 200:
        print(f"❌ Error: {response.status_code}")
        print(response.text)
        return

    data = response.json()
    droplets = data.get('droplets', [])

    print("\n" + "="*80)
    print("DROPLETS DISPONIBLES EN DIGITAL OCEAN")
    print("="*80 + "\n")

    if not droplets:
        print("No se encontraron droplets")
        return

    for droplet in droplets:
        networks = droplet.get('networks', {})
        v4 = networks.get('v4', [])
        ip_address = v4[0]['ip_address'] if v4 else 'N/A'

        print(f"ID:       {droplet['id']}")
        print(f"Nombre:   {droplet['name']}")
        print(f"IP:       {ip_address}")
        print(f"Estado:   {droplet['status']}")
        print(f"Región:   {droplet['region']['name']}")
        print(f"Tamaño:   {droplet['size_slug']}")
        print(f"vCPUs:    {droplet['vcpus']}")
        print(f"RAM:      {droplet['memory']} MB")
        print(f"Disco:    {droplet['disk']} GB")
        print(f"Imagen:   {droplet['image']['distribution']} {droplet['image'].get('name', '')}")
        print("-" * 80)

    print()

def list_domains(token):
    """Lista todos los dominios configurados"""
    url = "https://api.digitalocean.com/v2/domains"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    response = requests.get(url, headers=headers)

    if response.status_code != 200:
        print(f"❌ Error: {response.status_code}")
        print(response.text)
        return

    data = response.json()
    domains = data.get('domains', [])

    print("\n" + "="*80)
    print("DOMINIOS CONFIGURADOS")
    print("="*80 + "\n")

    if not domains:
        print("No se encontraron dominios")
        return

    for domain in domains:
        print(f"Dominio:  {domain['name']}")
        print(f"TTL:      {domain.get('ttl', 'N/A')}")
        print("-" * 80)

    print()

if __name__ == "__main__":
    print("🔐 Cargando token desde .env...")
    env = load_env()

    token = env.get('DIGITALOCEAN_TOKEN')

    if not token or token == 'your-new-token-after-rotation':
        print("❌ Error: DIGITALOCEAN_TOKEN no está configurado en .env")
        print("   1. Ve a https://cloud.digitalocean.com/account/api/tokens")
        print("   2. Genera un nuevo token")
        print("   3. Agrégalo a .env como DIGITALOCEAN_TOKEN=...")
        exit(1)

    print("✓ Token cargado\n")

    list_droplets(token)
    list_domains(token)
