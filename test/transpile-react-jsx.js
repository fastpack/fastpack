import React from 'react'

<div />;

<div className="x" />;

<div className="x" y={1} />;

<div {...props} />;

<div className="x" {...props} />;

<div className="x" {...props} width={100} />;

<div>some</div>;

<div> some </div>;

<div>{some}</div>;

<div>X {some}</div>;

<div>X {some} Y</div>;

<div> X {some} Y </div>;

<div>
  X {some} Y
</div>;

<>some thing</>;

<>
  <div />
  <a />
</>;

<><div /> <a /></>;

<div>
  <>oops</>
</div>;

<div>
  <><div /><div /></>
</div>;

const App = ({ components }) => (
  <div>
    {components.map((Comp, i) => (
      <div key={i}>
        <Comp />
      </div>
    ))}
  </div>
);

<X component={true ? <Comp1 /> : <Comp2 />}/>;
<X>{/*
<div></div>
*/}</X>;
