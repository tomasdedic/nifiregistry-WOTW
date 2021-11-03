# nifiregistry-WOTW
Pozor predgenerovana CA pocita s nazvem nifi-ca a ma tak vygenerovane certifikaty, jelikoz tento nazev je generovan na zaklade .Chart.Name je potreba pouzit nazev "nifi".  
Pokud to chcete zmenit a pouzivat jiny nazev je potreba certifikaty pregenerovat,popis v  **charts/ca/cacert/README.md**
```sh
helm template nifi . --output-dir render --namespace nifi-registry -f values.yaml
```
```sh
helm install nifi .  --namespace nifi-registry -f values.yaml
```

