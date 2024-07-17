import requests
import json

def get_superheroes(api_url):

    response = requests.get(api_url)

    if response.status_code == 200:
 
        return response.json()
    else:

        raise Exception(f"Error al obtener datos de la API. Código de estado: {response.status_code}")

def analyze_superheroes(superheroes):
  
    comic_count = {}
    

    for hero in superheroes:
        comic = hero.get('comic', 'Unknown')
        if comic in comic_count:
            comic_count[comic] += 1
        else:
            comic_count[comic] = 1
    
    return comic_count

def main():
    api_url = 'http://localhost:8082/api/superheroes'
    

    superheroes = get_superheroes(api_url)
    

    print("Datos obtenidos de la API:")
    print(json.dumps(superheroes, indent=4))
    

    analysis_result = analyze_superheroes(superheroes)

    print("\nResultado del análisis (número de superhéroes por cómic):")
    print(json.dumps(analysis_result, indent=4))

if __name__ == "__main__":
    main()
