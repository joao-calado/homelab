# 7. Anti‑cache e cabeçalho X‑Pod‑Name

A versão básica da aplicação tem uma limitação: o navegador utiliza keep‑alive (conexões HTTP persistentes), então parece que sempre o mesmo pod responde, mascarando o balanceamento de carga. Além disso, o conteúdo HTML é idêntico em todos os pods, dificultando a depuração.

**Solução:**  
1. Gerar o `index.html` com o nome do pod (`$MY_POD_NAME`).  
2. Adicionar cabeçalhos HTTP anti‑cache para forçar o navegador a buscar a página novamente a cada requisição.  
3. Adicionar o cabeçalho `X-Pod-Name` para revelar qual pod respondeu.

---

## 7.1. Manifiesto final (com anti‑cache)

O Deployment abaixo já incorpora todas as melhorias. O arquivo completo está no repositório como `manifests/app.yaml`.

1. Conteúdo do `manifests/app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-teste
  template:
    metadata:
      labels:
        app: nginx-teste
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        env:
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "<h1>Respondido pelo Pod: $MY_POD_NAME</h1>" > /usr/share/nginx/html/index.html
            cat > /tmp/default.conf.template <<'EOF'
            server {
                listen       80;
                server_name  localhost;
                location / {
                    root   /usr/share/nginx/html;
                    index  index.html index.htm;
                    add_header Cache-Control "no-cache, no-store, must-revalidate";
                    add_header Pragma "no-cache";
                    add_header Expires "0";
                    add_header X-Pod-Name "__POD_NAME__";
                }
            }
            EOF
            sed "s/__POD_NAME__/$MY_POD_NAME/" /tmp/default.conf.template > /etc/nginx/conf.d/default.conf
            nginx -g 'daemon off;'
        resources:
          requests:
            cpu: "300m"
            memory: "512Mi"
          limits:
            cpu: "300m"
            memory: "512Mi"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: nginx-teste
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  rules:
  - host: nginx.192.168.1.200.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

2. Aplicar o manifesto:

```sh
kubectl apply -f manifests/app.yaml
```

Descrição:

```text
O Kubernetes fará um rolling update: os pods antigos serão terminados gradativamente e novos pods com a configuração anti‑cache serão criados.
```

---

## 7.2. Explicação do comando dentro do container

O trecho abaixo é executado no momento em que cada pod é criado:

```bash
# 1. Cria o index.html com o nome do pod
echo "<h1>Respondido pelo Pod: $MY_POD_NAME</h1>" > /usr/share/nginx/html/index.html

# 2. Cria um template de configuração do Nginx com placeholders
cat > /tmp/default.conf.template <<'EOF'
server {
    listen       80;
    location / {
        root   /usr/share/nginx/html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
        add_header X-Pod-Name "__POD_NAME__";
    }
}
EOF

# 3. Substitui o placeholder pelo nome real do pod
sed "s/__POD_NAME__/$MY_POD_NAME/" /tmp/default.conf.template > /etc/nginx/conf.d/default.conf

# 4. Inicia o Nginx em foreground
nginx -g 'daemon off;'
```

Descrição dos cabeçalhos adicionados:

```text
Cache-Control: no-cache, no-store, must-revalidate → Impede que o navegador armazene a resposta em cache.
Pragma: no-cache → Versão antiga do no-cache (compatibilidade com navegadores legados).
Expires: 0 → Indica que o conteúdo já expirou.
X-Pod-Name: <nome> → Cabeçalho personalizado que identifica qual pod respondeu a requisição.
```

---

## 7.3. Verificar os cabeçalhos de resposta com `curl`

1. Comando:

```sh
curl -I http://nginx.192.168.1.200.nip.io
```

2. Exemplo de saída:

```text
HTTP/1.1 200 OK
Cache-Control: no-cache, no-store, must-revalidate
Pragma: no-cache
Expires: 0
X-Pod-Name: web-server-abcde-12345
...
```

Repita o comando algumas vezes. O valor de `X-Pod-Name` deve alternar entre os dois pods (ou mais, se você escalou).

---

## 7.4. Testar no navegador

1. Abra o navegador e acesse `http://nginx.192.168.1.200.nip.io`.  
2. Abra as ferramentas de desenvolvedor (F12) → aba **Network**.  
3. Atualize a página com **Ctrl+F5** (recarga forçada, ignorando caches).  
4. Clique na requisição principal e examine os cabeçalhos de resposta:  
   - `X-Pod-Name` mostrará o nome do pod.  
   - `Cache-Control` estará presente com valores `no-cache, no-store...`.  

Cada atualização forçada (ou uma nova aba) deve trazer um pod diferente, confirmando o balanceamento.

---

## Observação

```text
Sem os cabeçalhos anti‑cache, o navegador reutiliza a mesma conexão TCP (keep‑alive) e não evidencia a alternância entre pods. Adicionalmente, a página HTML agora exibe o nome do pod que a gerou, visível diretamente no corpo da resposta.
```

---

## ✅ Próximo passo

Com a aplicação devidamente depurável, vamos aprender a monitorar o cluster em tempo real:

👉 [08-monitoramento.md](08-monitoramento.md)
