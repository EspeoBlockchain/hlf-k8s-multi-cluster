# Getting domains on Freenom

### Main page
Type in domain name that you want to get and press check availability
![Main page](./images/1.png)

### Adding domains to the cart
If you find available domains and they're all in the cart, proceed to checkout
![Adding domains to cart](./images/2.png)

### Cart view
In cart view, you can select up to 12 months for free
![Cart view](./images/3.png)

### Account view
After you "buy" the domains, go to Services -> My Domains
![Logged in view](./images/4.png)

### My domains view
Here open all "Manage Domain" options in new tabs
![My domains](./images/5.png)

### Manage domain view
In each tab go to "Manage Freenom DNS"
![Manage domain screen](./images/6.png)

### Getting public IP
To get public IP addresses of the cluster, type in this command (after Istio is installed on the cluster, it might take a few minutes to assign an EXTERNAL-IP)

`kubectl get svc istio-ingressgateway -n istio-system`
![How to take IP address](./images/7.png)

### Organization configs
Create entries on the website according to the screens below
![Org1 config](./images/8.png)

![Org2 config](./images/9.png)

![Orderer config](./images/10.png)
