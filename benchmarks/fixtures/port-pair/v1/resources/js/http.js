import axios from 'axios';

// Laravel sets the XSRF-TOKEN cookie; axios echoes it in X-XSRF-TOKEN on every same-site write.
axios.defaults.withCredentials = true;
axios.defaults.xsrfCookieName = 'XSRF-TOKEN';
axios.defaults.xsrfHeaderName = 'X-XSRF-TOKEN';

export default axios;
