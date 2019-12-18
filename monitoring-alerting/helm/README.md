### Installation

```bash
helm install spin stable/prometheus-operator -f values.yml -n monitoring
```

### Google OAuth Client Setup

Google OAuth is setup for this installation of grafana, limiting to the domain `homedepot.com`. After running the installation command you'll need to edit the yaml of the `spin-grafana` pod environment variables to include the following:

```
        - name: GF_AUTH_GOOGLE_CLIENT_ID
          value: <CLIENT_ID>
        - name: GF_AUTH_GOOGLE_CLIENT_SECRET
          value: <CLIENT_SECRET>
```

Delete the grafana pod to allow the environment variables to propagate. 
